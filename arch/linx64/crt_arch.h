__asm__(
".text\n"
".global " START "\n"
".type " START ",%function\n"
START ":\n"
"C.BSTART.STD\n"
"c.movr\tsp,\t->a0\n"
"BSTART\tCALL, " START "_c, ra=1f\n"
"C.BSTOP\n"
"1:\n"
"C.BSTART\tDIRECT, 1b\n"
"C.BSTOP\n"
);
