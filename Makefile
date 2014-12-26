CC     = gcc
OBJS   = lib/hashtb.o lex.yy.o y.tab.o
LEX_C  = lex.yy.c
LEX_L  = lex.l
YACC_C = y.tab.c
YACC_H = y.tab.h
YACC_Y = parser.y
FINAL  = parser

all: ${FINAL}

${FINAL}: ${OBJS}
	${CC} -o parser -ll -ly ${OBJS}

%.o: %.c
	${CC} -c -g -o $@ $<

${YACC_C}: ${YACC_Y}
	yacc -d -v --debug --verbose ${YACC_Y}

${YACC_H}: ${YACC_Y}
	yacc -d -v --debug --verbose ${YACC_Y}

${LEX_C}: ${LEX_L} ${YACC_H}
	lex ${LEX_L}

clean:
	rm -rf ${LEX_C} ${FINAL} ${OBJS} ${YACC_C} y.*
