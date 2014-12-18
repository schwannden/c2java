%{
//predefined keyword
#include "lib/common.h"
#include "lib/symbolTable.h"
#include "lib/hashtb.h"
#include "y.tab.h"
#define LIST                { strncat(buf, yytext, sizeof(buf) - strlen(buf) - 1); }
#define token(t)            { LIST; if (Opt_Token) printf("<%s>\n", t); }
#define tokenString(t, s)   { LIST; if (Opt_Token) printf("<%s:%s>\n", t, s); }
//initial variables
int Opt_Source = 0;
int Opt_Token = 0;
int Opt_Statistic = 0;
int linenum = 1;
char buf[MAX_LINE_LENGTH];
char stringBuf[MAX_LINE_LENGTH];
struct SymbolTable symbolTable;
struct hashtb* st;
struct hashtb_enumerator* ste;
char* quote (char* target, char* src)
{
  int n = strlen (src), i;
  target[0]   = '\"';
  target[1]   = '\0';
  strncat (target, src, n);
  target[n+1] = '\"';
  target[n+2] = '\0';
  return target;
}
char* unquote (char* target, char* src)
{
  int n = strlen (src) - 2, i;
  strncpy(target, src+1, n);
  return target;
}
void addID (const char* id)
{
    hashtb_seek (ste, (void*) id, strlen(id), 1);
    int * frequency = hashtb_lookup (st, (void*)id, strlen(id));
    (*frequency)++;
}
void endOfLine ()
{
    LIST;
    if (Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
}
void errorLex()
{
    fprintf(stderr, "Error at line %d: %s\n", linenum, yytext);
    exit(1);
}
//\"(\\.|[^\\\n"])*\"                    { tokenString ("string", unquote (stringBuf, yytext)); }
%}
digit     [0-9]
letter    [a-zA-Z]
integer   0|([1-9]{digit}*)
float     {digit}+\.{digit}+
directive "source"|"statistics"|"token"
%x BCOMMENT LCOMMENT DIRECTIVE DIRECTIVEEND D_STATISTIC D_SOURCE D_TOKEN D_STRING

%%
<INITIAL,DIRECTIVEEND>"/*" { BEGIN BCOMMENT; LIST; }
<INITIAL,DIRECTIVEEND>"//" { BEGIN LCOMMENT; LIST; }
<BCOMMENT>\n            endOfLine();
<BCOMMENT,LCOMMENT>.    LIST;
<BCOMMENT>"*/"          { BEGIN INITIAL; LIST; }
<LCOMMENT>\n            { BEGIN INITIAL; endOfLine(); }
^"#pragma"[ \t]+             {LIST; BEGIN DIRECTIVE;}
<DIRECTIVE>"source"[ \t]+    {LIST; BEGIN D_SOURCE;}
<DIRECTIVE>"statistic"[ \t]+ {LIST; BEGIN D_STATISTIC;}
<DIRECTIVE>"token"[ \t]+     {LIST; BEGIN D_TOKEN;;}
<D_STATISTIC>"on"[ \t]*     {LIST;  BEGIN DIRECTIVEEND; Opt_Statistic = 1;}
<D_STATISTIC>"off"[ \t]*    {LIST;  BEGIN DIRECTIVEEND; Opt_Statistic = 0;}
<D_SOURCE>"on"[ \t]*        {LIST;  BEGIN DIRECTIVEEND; Opt_Source = 1;}
<D_SOURCE>"off"[ \t]*       {LIST;  BEGIN DIRECTIVEEND; Opt_Source = 0;}
<D_TOKEN>"on"[ \t]*         {LIST;  BEGIN DIRECTIVEEND; Opt_Token = 1;}
<D_TOKEN>"off"[ \t]*        {LIST;  BEGIN DIRECTIVEEND; Opt_Token = 0;}
<DIRECTIVE,D_STATISTIC,D_SOURCE,D_TOKEN>. errorLex ();
<DIRECTIVEEND>\n   { BEGIN INITIAL; endOfLine(); }
<DIRECTIVEEND>[^\n] errorLex ();

while                                { tokenString ("KW", yytext); return WHILE; }
do                                   { tokenString ("KW", yytext); return DO; }
if                                   { tokenString ("KW", yytext); return IF; }
else                                 { tokenString ("KW", yytext); return ELSE; }
true                                 { tokenString ("KW", yytext); return TRUE; }
false                                { tokenString ("KW", yytext); return FALSE; }
for                                  { tokenString ("KW", yytext); return FOR; }
int                                  { tokenString ("KW", yytext); return INT; }
print                                { tokenString ("KW", yytext); return PRINT; }
const                                { tokenString ("KW", yytext); return CONST; }
read                                 { tokenString ("KW", yytext); return READ; }
boolean                              { tokenString ("KW", yytext); return BOOL; }
bool                                 { tokenString ("KW", yytext); return BOOL; }
void                                 { tokenString ("KW", yytext); return VOID; }
float                                { tokenString ("KW", yytext); return FLOAT; }
double                               { tokenString ("KW", yytext); return DOUBLE; }
string                               { tokenString ("KW", yytext); return STRING; }
continue                             { tokenString ("KW", yytext); return CONTINUE; }
break                                { tokenString ("KW", yytext); return BREAK; }
return                               { tokenString ("KW", yytext); return RETURN; }

[-+*/%<>!=]                          { token (quote (stringBuf,yytext)); return yytext[0]; }
"<="                                 { token (quote (stringBuf,yytext)); return LTE; }
">="                                 { token (quote (stringBuf,yytext)); return GTE; }
"!="                                 { token (quote (stringBuf,yytext)); return NEQ; }
"=="                                 { token (quote (stringBuf,yytext)); return EQ;  }
"&&"                                 { token (quote (stringBuf,yytext)); return AND; }
"||"                                 { token (quote (stringBuf,yytext)); return OR;  }

[(){},;\[\]]                         { tokenString ("delim", yytext); return yytext[0]; }
{integer}                            { tokenString ("integer", yytext); return LITERAL_INT; }
{float}                              { tokenString ("float", yytext); return LITERAL_FLOAT; }
({float}|{integer})(e|E)[-+]?{digit}+{ tokenString ("scientific", yytext); return LITERAL_FLOAT; }
{letter}+({letter}|{digit})*         { tokenString ("id", yytext); addID(yytext); return ID; }
<INITIAL>\"                          { LIST; BEGIN D_STRING; stringBuf[0] = '\0'; }
<D_STRING>\n                         { LIST; errorLex (); }
<D_STRING>\\\"                       { LIST; strcat (stringBuf, "\""); }
<D_STRING>\\[^"]|[^\\\n"]            { LIST; strcat (stringBuf, yytext); }
<D_STRING>\"                         { BEGIN INITIAL; tokenString ("string", stringBuf); return LITERAL_STRING; }

\n                                     endOfLine();
[\t ]                                  LIST; //ignored charactor
.                                      errorLex ();
%%

/*int main( int argc, char **argv )
{
    if (argc >= 2)
    {
        yyin = fopen( argv[1], "r" );
        if ( NULL == yyin ) {
            fprintf( stderr, "Cannot open: %s\n", argv[1] );
            exit(-1);
        }
    }
    else
    {
        yyin = stdin;
    }

    yylex();

    if (Opt_Statistic)
    {
        int i;
        hashtb_end (ste);
        hashtb_start (st, ste);
        printf ("frequencies of identifiers:\n");
        while (ste->key != NULL)
          {
             printf ("%s\t%d\n", ste->key, *(int*)(ste->data));
             hashtb_next (ste);
          }
    }

    exit(0);
} */

