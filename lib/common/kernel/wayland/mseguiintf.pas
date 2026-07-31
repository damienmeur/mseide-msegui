{ MSEgui - Wayland backend, work in progress.
  Drafted with AI assistance, in the shape argot#312 describes. }
unit mseguiintf; //Wayland

{$ifdef FPC}{$mode objfpc}{$h+}{$GOTO ON}{$interfaces corba}{$endif}

interface
uses
 msetypes, mseguiglob, msegraphutils, mseevent, msesystypes;

{$include ../mseguiintf.inc}

implementation
uses
 mseapplication, msegraphics;

// stubbed for now, body to follow
function gui_postevent(event: tmseevent): guierrorty; forward;

function gui_init: guierrorty;
begin
 result:= gue_ok;
end;

function gui_deinit: guierrorty;
begin
 result:= gue_ok;
end;

procedure gui_cancelshutdown;
begin
end;

function gui_setmainthread: guierrorty;
begin
 result:= gue_ok;
end;

function gui_registergdi: guierrorty;
begin
 result:= gue_ok;
end;

function gui_sethighrestimer(const avalue: boolean): guierrorty;
begin
 result:= gue_ok;
end;

function gui_set_timer(us: longword): guierrorty;
begin
 result:= gue_ok;
end;

end.
