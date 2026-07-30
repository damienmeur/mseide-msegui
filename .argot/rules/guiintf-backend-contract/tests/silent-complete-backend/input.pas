unit mseguiintf; //X11
interface
{$include ../mseguiintf.inc}
implementation
function gui_init: guierrorty;
begin
 result:= ge_ok;
end;

function gui_deinit: guierrorty;
begin
 result:= ge_ok;
end;
end.
