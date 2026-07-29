unit mseopensslsha;

{$ifdef FPC}{$mode objfpc}{$h+}{$endif}

interface

implementation
uses
 sysutils;

procedure setupcrypto;
begin
 regopensslinit(@init);
end;

end.
