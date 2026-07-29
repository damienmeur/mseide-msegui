unit msesomehelper;

{$ifdef FPC}{$mode objfpc}{$h+}{$endif}

interface

implementation
uses
 sysutils;

function addtwo(const a: integer; const b: integer): integer;
begin
 result:= a + b;
end;

end.
