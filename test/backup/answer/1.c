1:// print hello world

<KW:void>
<id:main>
<delim:(>
<delim:)>
2:void main()

<delim:{>
3:{

<KW:int>
<id:a>
<delim:;>
4:  int a;

<KW:double>
<id:b>
<delim:;>
5:  double b;

<KW:print>
<string:hello world>
<delim:;>
6:  print "hello world";

<id:a>
<"=">
<integer:1>
<"+">
<integer:1>
<delim:;>
7:  a = 1+1;

<id:b>
<"=">
<float:1.23>
<delim:;>
8:  b = 1.23;

<KW:if>
<delim:(>
<id:a>
<">">
<integer:1>
<delim:)>
<delim:{>
9:  if (a > 1){

<id:b>
<"=">
<id:b>
<"*">
<scientific:1.23e-1>
<delim:;>
10:    b = b*1.23e-1;

<delim:}>
11:  }

<delim:}>
12:}

frequencies of identifiers:
main  1
a 3
b 4
