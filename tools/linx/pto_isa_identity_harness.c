#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

#define ElfW(type) Elf64_##type

typedef struct {
	uint32_t n_namesz;
	uint32_t n_descsz;
	uint32_t n_type;
} Elf64_Nhdr;

typedef struct {
	uint32_t p_type;
	uint32_t p_flags;
	uint64_t p_offset;
	uint64_t p_vaddr;
	uint64_t p_paddr;
	uint64_t p_filesz;
	uint64_t p_memsz;
	uint64_t p_align;
} Elf64_Phdr;

typedef Elf64_Phdr Phdr;

#define PT_LOAD 1
#define PT_NOTE 4
#define ELF_NOTE_PTO "PTO"
#define PTO_NT_ISA_IDENTITY 1
#define PTO_ISA_IDENTITY_JSON \
	"{\"encoding_abi\":\"pto-isa-0.58.3-mode-function-v1\"," \
	"\"encoding_projection_sha256\":" \
	"\"8a48b80e04484c70870f155bf9efc79d2a805cf99e809f4e4e8a7e6a7eb34172\"," \
	"\"release\":\"0.58.3\"}"
#define PTO_ISA_OLD_IDENTITY_JSON \
	"{\"encoding_abi\":\"pto-isa-0.58.1-mode-function-v1\"," \
	"\"encoding_projection_sha256\":" \
	"\"89b872d6eaf0252200bc9349d49b9346e2a69d894cdcc2dcd0fd71911c1e0b8c\"," \
	"\"release\":\"0.58.1\"}"
#define PTO_NOTE_SCAN_MAX 4096
#define PTO_ISA_OFFSET_MAX ((uintmax_t)INT64_MAX)

#include "../../ldso/pto_isa_identity.h"

struct read_ctx {
	const unsigned char *data;
	size_t len;
	size_t max_chunk;
	int eintr_count;
	int error_count;
};

struct map_ctx {
	const unsigned char *data;
};

static size_t align4(size_t value)
{
	return (value + 3) & ~(size_t)3;
}

static size_t make_note(unsigned char *out, const char *name,
	uint32_t note_type, const unsigned char *desc, size_t desc_len)
{
	size_t name_len = strlen(name) + 1;
	Elf64_Nhdr nhdr = { name_len, desc_len, note_type };
	size_t name_off = sizeof nhdr;
	size_t desc_off = name_off + align4(name_len);
	size_t next = desc_off + align4(desc_len);

	memcpy(out, &nhdr, sizeof nhdr);
	memcpy(out + name_off, name, name_len);
	memset(out + name_off + name_len, 0, align4(name_len) - name_len);
	memcpy(out + desc_off, desc, desc_len);
	memset(out + desc_off + desc_len, 0, align4(desc_len) - desc_len);
	return next;
}

static ssize_t fixture_read_at(void *opaque, unsigned char *buf, size_t len, uintmax_t off)
{
	struct read_ctx *ctx = opaque;
	if (ctx->eintr_count) {
		ctx->eintr_count--;
		errno = EINTR;
		return -1;
	}
	if (ctx->error_count) {
		ctx->error_count--;
		errno = EIO;
		return -1;
	}
	if (off >= ctx->len) return 0;
	size_t avail = ctx->len - off;
	size_t n = avail < len ? avail : len;
	if (ctx->max_chunk && n > ctx->max_chunk) n = ctx->max_chunk;
	memcpy(buf, ctx->data + off, n);
	return n;
}

static const unsigned char *fixture_map_addr(void *opaque, size_t vaddr)
{
	struct map_ctx *ctx = opaque;
	return ctx->data + vaddr;
}

static Phdr load_phdr(uint64_t vaddr, uint64_t memsz)
{
	Phdr ph = {0};
	ph.p_type = PT_LOAD;
	ph.p_vaddr = vaddr;
	ph.p_memsz = memsz;
	return ph;
}

static Phdr note_phdr(uint64_t off, uint64_t vaddr, uint64_t filesz,
	uint64_t memsz, uint64_t align)
{
	Phdr ph = {0};
	ph.p_type = PT_NOTE;
	ph.p_offset = off;
	ph.p_vaddr = vaddr;
	ph.p_filesz = filesz;
	ph.p_memsz = memsz;
	ph.p_align = align;
	return ph;
}

static int expect_state(const char *name, struct pto_isa_identity_state state,
	int valid, int invalid)
{
	if (state.valid == valid && state.invalid == invalid) return 0;
	fprintf(stderr, "%s: expected valid=%d invalid=%d, got valid=%d invalid=%d\n",
		name, valid, invalid, state.valid, state.invalid);
	return 1;
}

static int run_fd_case(const char *name, const unsigned char *file, size_t file_len,
	const Phdr *phdrs, size_t phnum, struct read_ctx ctx,
	int valid, int invalid)
{
	struct pto_isa_identity_state state = {0};
	ctx.data = file;
	ctx.len = file_len;
	pto_isa_process_fd_notes(&state, phdrs, phnum, sizeof phdrs[0],
		fixture_read_at, &ctx);
	return expect_state(name, state, valid, invalid);
}

static int run_map_case(const char *name, const unsigned char *map,
	const Phdr *phdrs, size_t phnum, int valid, int invalid)
{
	struct pto_isa_identity_state state = {0};
	struct map_ctx ctx = { map };
	pto_isa_process_mapped_notes(&state, phdrs, phnum, sizeof phdrs[0],
		0, fixture_map_addr, &ctx);
	return expect_state(name, state, valid, invalid);
}

int main(void)
{
	unsigned char good[256] = {0};
	unsigned char mismatch[256] = {0};
	unsigned char trailing_nul[256] = {0};
	unsigned char other[64] = {0};
	unsigned char file[8192] = {0};
	unsigned char map[8192] = {0};
	const unsigned char *desc = (const unsigned char *)PTO_ISA_IDENTITY_JSON;
	size_t desc_len = strlen(PTO_ISA_IDENTITY_JSON);
	size_t good_len = make_note(good, ELF_NOTE_PTO, PTO_NT_ISA_IDENTITY,
		desc, desc_len);
	const char bad_desc[] = PTO_ISA_OLD_IDENTITY_JSON;
	size_t mismatch_len = make_note(mismatch, ELF_NOTE_PTO, PTO_NT_ISA_IDENTITY,
		(const unsigned char *)bad_desc, desc_len);
	size_t trailing_nul_len = make_note(trailing_nul, ELF_NOTE_PTO,
		PTO_NT_ISA_IDENTITY, desc, desc_len + 1);
	size_t other_len = make_note(other, "GNU", 3,
		(const unsigned char *)"build-id", 8);
	int fails = 0;

	memcpy(file, good, good_len);
	Phdr valid = note_phdr(0, 0, good_len, good_len, 4);
	fails += run_fd_case("valid", file, good_len, &valid, 1,
		(struct read_ctx){ .max_chunk = 7, .eintr_count = 2 }, 1, 0);

	memset(file, 0, sizeof file);
	memcpy(file, mismatch, mismatch_len);
	Phdr mismatch_ph = note_phdr(0, 0, mismatch_len, mismatch_len, 4);
	fails += run_fd_case("old-0.58.1", file, mismatch_len, &mismatch_ph, 1,
		(struct read_ctx){0}, 0, 1);

	memset(file, 0, sizeof file);
	memcpy(file, good, good_len);
	memcpy(file + good_len, mismatch, mismatch_len);
	Phdr conflict = note_phdr(0, 0, good_len + mismatch_len,
		good_len + mismatch_len, 4);
	fails += run_fd_case("conflict", file, good_len + mismatch_len, &conflict, 1,
		(struct read_ctx){0}, 0, 1);

	memset(file, 0, sizeof file);
	memcpy(file, good, good_len);
	memcpy(file + good_len, good, good_len);
	Phdr duplicate = note_phdr(0, 0, good_len * 2, good_len * 2, 4);
	fails += run_fd_case("duplicate-identical", file, good_len * 2,
		&duplicate, 1, (struct read_ctx){0}, 1, 0);

	memset(file, 0, sizeof file);
	memcpy(file, trailing_nul, trailing_nul_len);
	Phdr nul_ph = note_phdr(0, 0, trailing_nul_len, trailing_nul_len, 4);
	fails += run_fd_case("trailing-nul", file, trailing_nul_len, &nul_ph, 1,
		(struct read_ctx){0}, 0, 1);

	memset(file, 0, sizeof file);
	memcpy(file, good, good_len);
	file[good_len] = 1;
	Phdr malformed = note_phdr(0, 0, good_len + 1, good_len + 1, 4);
	fails += run_fd_case("malformed", file, good_len + 1, &malformed, 1,
		(struct read_ctx){0}, 0, 1);

	memset(file, 'x', sizeof file);
	Phdr oversized = note_phdr(0, 0, PTO_NOTE_SCAN_MAX + 1,
		PTO_NOTE_SCAN_MAX + 1, 4);
	fails += run_fd_case("oversized", file, sizeof file, &oversized, 1,
		(struct read_ctx){0}, 0, 1);

	memset(file, 0, sizeof file);
	memcpy(file, other, other_len);
	Phdr missing = note_phdr(0, 0, other_len, other_len, 4);
	fails += run_fd_case("missing", file, other_len, &missing, 1,
		(struct read_ctx){0}, 0, 0);

	memset(file, 0, sizeof file);
	memcpy(file, mismatch, mismatch_len);
	memcpy(file + 512, good, good_len);
	Phdr skip_then_valid[] = {
		note_phdr(0, 0, mismatch_len, mismatch_len, 8),
		note_phdr(512, 512, good_len, good_len, 4),
	};
	fails += run_fd_case("valid+unrelated-non4", file, 512 + good_len,
		skip_then_valid, 2, (struct read_ctx){ .max_chunk = 5 }, 1, 0);

	memset(file, 0, sizeof file);
	memcpy(file, good, good_len);
	fails += run_fd_case("partial-read", file, good_len - 1, &valid, 1,
		(struct read_ctx){0}, 0, 1);
	fails += run_fd_case("read-error", file, good_len, &valid, 1,
		(struct read_ctx){ .error_count = 1 }, 0, 1);
	Phdr offset_overflow = note_phdr((uint64_t)INT64_MAX + 1, 0,
		good_len, good_len, 4);
	fails += run_fd_case("offset-overflow", file, good_len, &offset_overflow, 1,
		(struct read_ctx){0}, 0, 1);

	memset(map, 0, sizeof map);
	memcpy(map + 128, good, good_len);
	Phdr mapped_ok[] = {
		load_phdr(0, 512),
		note_phdr(0, 128, good_len, good_len, 4),
	};
	fails += run_map_case("mapped-valid", map, mapped_ok, 2, 1, 0);

	Phdr filesz_gt_memsz[] = {
		load_phdr(0, 512),
		note_phdr(0, 128, good_len, good_len - 1, 4),
	};
	fails += run_map_case("mapped-filesz-gt-memsz", map, filesz_gt_memsz, 2, 0, 1);

	Phdr nonloaded[] = {
		load_phdr(0, 64),
		note_phdr(0, 128, good_len, good_len, 4),
	};
	fails += run_map_case("mapped-nonloaded-range", map, nonloaded, 2, 0, 1);

	Phdr empty_nonloaded[] = {
		load_phdr(0, 64),
		note_phdr(0, 128, 0, good_len, 4),
	};
	fails += run_map_case("mapped-empty-nonloaded-range", map,
		empty_nonloaded, 2, 0, 0);

	if (fails) return 1;
	puts("ok: PTO ISA identity C harness");
	return 0;
}
