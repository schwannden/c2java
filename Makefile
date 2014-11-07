CC     = gcc
OBJS   = lib/symbolTable.o lib/hashtb.o lex.yy.o 
LEX_C  = lex.yy.c
LEX_L  = lex.l
FINAL  = scanner

all: ${FINAL}

scanner: ${OBJS}
	${CC} -o ${FINAL} -ll ${OBJS}

%.o: %.c
	${CC} -c -o $@ $<

${LEX_C}: ${LEX_L}
	lex ${LEX_L}

clean:
	rm -rf ${LEX_C} ${FINAL} ${OBJS}
