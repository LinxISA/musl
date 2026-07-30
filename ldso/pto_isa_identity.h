#ifndef PTO_ISA_IDENTITY_H
#define PTO_ISA_IDENTITY_H

#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>

#ifndef PTO_ISA_OFFSET_MAX
#define PTO_ISA_OFFSET_MAX ((uintmax_t)-1)
#endif

struct pto_isa_identity_state {
	char valid;
	char invalid;
};

typedef ssize_t pto_isa_read_at_fn(void *, unsigned char *, size_t, uintmax_t);
typedef const unsigned char *pto_isa_map_addr_fn(void *, size_t);

static void pto_isa_reject(struct pto_isa_identity_state *state)
{
	state->valid = 0;
	state->invalid = 1;
}

static int pto_isa_add_overflow(size_t a, size_t b, size_t *out)
{
	*out = a + b;
	return *out < a;
}

static int pto_isa_note_bytes(struct pto_isa_identity_state *state,
	const unsigned char *buf, size_t len)
{
	size_t off = 0;
	while (off < len) {
		if (len - off < sizeof(ElfW(Nhdr))) {
			pto_isa_reject(state);
			return -1;
		}
		const ElfW(Nhdr) *note = (const void *)(buf + off);
		size_t name_off = off + sizeof *note;
		size_t name_size = (note->n_namesz + 3) & -4;
		size_t desc_off, desc_size, next;
		if (name_size < note->n_namesz
		    || pto_isa_add_overflow(name_off, name_size, &desc_off)
		    || (desc_size = (note->n_descsz + 3) & -4) < note->n_descsz
		    || pto_isa_add_overflow(desc_off, desc_size, &next)
		    || next <= off || next > len
		    || desc_off > len || note->n_descsz > len - desc_off) {
			pto_isa_reject(state);
			return -1;
		}
		if (note->n_namesz == 4 && note->n_type == PTO_NT_ISA_IDENTITY
		    && !memcmp(buf + name_off, ELF_NOTE_PTO, 4)) {
			const char *desc = (const char *)buf + desc_off;
			size_t expected_len = sizeof PTO_ISA_IDENTITY_JSON - 1;
			if (note->n_descsz != expected_len
			    || memcmp(desc, PTO_ISA_IDENTITY_JSON, expected_len)) {
				pto_isa_reject(state);
				return -1;
			}
			state->valid = 1;
		}
		off = next;
	}
	return 0;
}

static int pto_isa_note_range_loaded(const Phdr *ph0, size_t phnum,
	size_t phentsize, size_t base, const Phdr *note_ph, size_t len)
{
	size_t start, end;
	if (pto_isa_add_overflow(base, note_ph->p_vaddr, &start)
	    || pto_isa_add_overflow(start, len, &end))
		return 0;

	const Phdr *ph = ph0;
	for (size_t i=phnum; i; i--, ph=(const void *)((const char *)ph+phentsize)) {
		size_t seg_start, seg_end;
		if (ph->p_type != PT_LOAD) continue;
		if (pto_isa_add_overflow(base, ph->p_vaddr, &seg_start)
		    || pto_isa_add_overflow(seg_start, ph->p_memsz, &seg_end))
			continue;
		if (start >= seg_start && end <= seg_end) return 1;
	}
	return 0;
}

static int pto_isa_read_exact(struct pto_isa_identity_state *state,
	pto_isa_read_at_fn *read_at, void *ctx, unsigned char *buf,
	size_t len, uintmax_t off)
{
	if (off > PTO_ISA_OFFSET_MAX || len > PTO_ISA_OFFSET_MAX - off) {
		pto_isa_reject(state);
		return -1;
	}

	size_t done = 0;
	while (done < len) {
		ssize_t l = read_at(ctx, buf + done, len - done, off + done);
		if (l < 0) {
			if (errno == EINTR) continue;
			pto_isa_reject(state);
			return -1;
		}
		if (!l) {
			pto_isa_reject(state);
			return -1;
		}
		done += l;
	}
	return 0;
}

static void pto_isa_process_fd_notes(struct pto_isa_identity_state *state,
	const Phdr *ph0, size_t phnum, size_t phentsize,
	pto_isa_read_at_fn *read_at, void *ctx)
{
	unsigned char buf[PTO_NOTE_SCAN_MAX] __attribute__((aligned(_Alignof(ElfW(Nhdr)))));
	const Phdr *ph = ph0;
	for (size_t i=phnum; i; i--, ph=(const void *)((const char *)ph+phentsize)) {
		if (ph->p_type != PT_NOTE) continue;
		if (ph->p_align != 4) continue;
		if (ph->p_filesz > sizeof buf) {
			pto_isa_reject(state);
			return;
		}
		if (!ph->p_filesz) continue;
		if (pto_isa_read_exact(state, read_at, ctx, buf,
		    ph->p_filesz, ph->p_offset) < 0)
			return;
		if (pto_isa_note_bytes(state, buf, ph->p_filesz) < 0) return;
	}
}

static void pto_isa_process_mapped_notes(struct pto_isa_identity_state *state,
	const Phdr *ph0, size_t phnum, size_t phentsize, size_t base,
	pto_isa_map_addr_fn *map_addr, void *ctx)
{
	const Phdr *ph = ph0;
	for (size_t i=phnum; i; i--, ph=(const void *)((const char *)ph+phentsize)) {
		if (ph->p_type != PT_NOTE) continue;
		if (ph->p_align != 4) continue;
		if (!ph->p_filesz) continue;
		if (ph->p_filesz > ph->p_memsz
		    || ph->p_filesz > PTO_NOTE_SCAN_MAX
		    || !pto_isa_note_range_loaded(ph0, phnum, phentsize, base,
		    ph, ph->p_filesz)) {
			pto_isa_reject(state);
			return;
		}
		if (pto_isa_note_bytes(state, map_addr(ctx, ph->p_vaddr),
		    ph->p_filesz) < 0)
			return;
	}
}

#endif
