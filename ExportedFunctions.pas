{
    Copyright (C) 2026 VCC
    creation date: 07 Nov 2026
    initial release date: 07 Nov 2026

    author: VCC
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
    OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}


unit ExportedFunctions;

{$IFDEF FPC}
  {$mode ObjFPC}{$H+}
{$ENDIF}

interface

uses
  Classes, SysUtils, MemStatPlugins;


procedure LoadLstFile(AFileName: Pointer; AFileNameLen: DWord); cdecl;
procedure LoadHexFile(AFileName: Pointer; AFileNameLen: DWord); cdecl;
function GetMemEntryCount: DWord; cdecl;
procedure GetMemEntry(AResultCallback: TGetMemEntryCallback; AEntryIndex: DWord); cdecl;  //AEntryIndex can go from 0 to GetMemEntryCount - 1
procedure GetStatistics(AResultCallback: TGetPluginStatisticsCallback; AMemTableInfo: TMemTableInfo); cdecl;


implementation


var
  FLstContent: TStringList;


procedure LoadLstFile(AFileName: Pointer; AFileNameLen: DWord); cdecl;
//var
//  FileName: string;
//  i: Integer;
//  s: string;
begin
  //SetLength(FileName, AFileNameLen);
  //Move(AFileName^, FileName[1], AFileNameLen);
  //FLstContent.LoadFromFile(FileName);
  //
  //for i := 0 to FLstContent.Count - 1 do
  //begin
  //  s := FLstContent.Strings[i];
  //
  //end; //for
end;


procedure LoadHexFile(AFileName: Pointer; AFileNameLen: DWord); cdecl;
begin

end;


function GetMemEntryCount: DWord; cdecl;
begin
  Result := 0;
end;


procedure GetMemEntry(AResultCallback: TGetMemEntryCallback; AEntryIndex: DWord); cdecl;  //AEntryIndex can go from 0 to GetMemEntryCount - 1
var
  Entry: TMemEntryAPI;
  TempEntryName: string;
begin
  if AResultCallback = nil then
    Exit;

  if AEntryIndex <> 0 then
    Exit;

  TempEntryName := 'Not implemented';
  Entry.Address := 0;
  Entry.Size := 0;
  Entry.EntryName := @TempEntryName[1];
  Entry.EntryNameLen := Length(TempEntryName);
  Entry.Index := AEntryIndex;

  AResultCallback(Entry);
  TempEntryName := '';
end;


function KSEGNameBySectionName(AKSegName, ASectionName: string): string;
begin
  Result := AKSegName;
  if (Pos('EBI', ASectionName) = 1) or (Pos('SQI', ASectionName) = 1) then
  begin
    if AKSegName = 'KSEG0' then
      Result := 'KSEG2';

    if AKSegName = 'KSEG1' then
      Result := 'KSEG3';
  end;
end;


procedure GetStatistics(AResultCallback: TGetPluginStatisticsCallback; AMemTableInfo: TMemTableInfo); cdecl;
type
  TAddressOffsets = array of record
    Seg1, Seg2: Integer;
  end;

  TEntryEndpoints = record
    //for SQI and EBI, these are KSEG2 and KSEG3, instead of KSEG0 and KSEG1:
    MinEntryAddr_KSEG0: Cardinal;
    MaxEntryAddr_KSEG0: Cardinal;
    MinEntryAddr_KSEG1: Cardinal;
    MaxEntryAddr_KSEG1: Cardinal;
    MinEntryAddrFound_KSEG0: Boolean;
    MaxEntryAddrFound_KSEG0: Boolean;
    MinEntryAddrFound_KSEG1: Boolean;
    MaxEntryAddrFound_KSEG1: Boolean;
  end;
  TEntryEndpointsArr = array of TEntryEndpoints;

  TSectionRange = record
    MinAddrSeg1, MinAddrSeg2, MaxAddrSeg1, MaxAddrSeg2: Cardinal;
  end;
  TSectionRangeArr = array of TSectionRange;

  TMemoryTranslationInfoAPIArr = array of TMemoryTranslationInfoAPI;

var
  TempStatistics: string;
  i, j: Integer;
  Entry, EntryEndAddress: Cardinal;
  DevName: string;
  IsPIC32: Boolean;
  AddressOffsets: TAddressOffsets;
  SectionNames: TStringArray;
  TempSectionNamePointer: Pointer;
  TempSectionNameLen: Cardinal;
  CurrentSectionName, KSeg0, KSeg1: string;
  AllEntryEndpoints: TEntryEndpointsArr;
  SectionRanges: TSectionRangeArr;
  MemoryTranslationInfos: TMemoryTranslationInfoAPIArr;
begin
  if AResultCallback = nil then
    Exit;

  SetLength(DevName, AMemTableInfo.DeviceNameLength);
  Move(AMemTableInfo.DeviceName^, DevName[1], Length(DevName));

  TempStatistics := 'Device: ' + DevName + #13#10 +
                    'Memory section count: ' + IntToStr(AMemTableInfo.SectionCount) + #13#10 +
                    'Routine entry count: ' + IntToStr(AMemTableInfo.MemContentLength) + #13#10 +
                    'Raw entry count: ' + IntToStr(AMemTableInfo.RawMemContentLength) + #13#10;

  IsPIC32 := Pos('PIC32', DevName) = 1;
  SetLength(AddressOffsets, AMemTableInfo.SectionCount);
  SetLength(SectionNames, AMemTableInfo.SectionCount);
  SetLength(AllEntryEndpoints, AMemTableInfo.SectionCount);
  SetLength(SectionRanges, AMemTableInfo.SectionCount);
  SetLength(MemoryTranslationInfos, AMemTableInfo.SectionCount);

  for j := 0 to AMemTableInfo.SectionCount - 1 do
  begin
    AMemTableInfo.GetAddressOffsetsCallback(j, AddressOffsets[j].Seg1, AddressOffsets[j].Seg2);

    AMemTableInfo.GetDefSectionNameCallback(j, TempSectionNamePointer, TempSectionNameLen);
    SetLength(SectionNames[j], TempSectionNameLen);
    Move(TempSectionNamePointer^, SectionNames[j][1], TempSectionNameLen);
  end;

  for j := 0 to AMemTableInfo.SectionCount - 1 do
  begin
    AllEntryEndpoints[j].MinEntryAddr_KSEG0 := $FFFFFFFF;
    AllEntryEndpoints[j].MinEntryAddr_KSEG1 := $FFFFFFFF;
    AllEntryEndpoints[j].MaxEntryAddr_KSEG0 := 0;
    AllEntryEndpoints[j].MaxEntryAddr_KSEG1 := 0;

    AllEntryEndpoints[j].MinEntryAddrFound_KSEG0 := False;
    AllEntryEndpoints[j].MaxEntryAddrFound_KSEG0 := False;
    AllEntryEndpoints[j].MinEntryAddrFound_KSEG1 := False;
    AllEntryEndpoints[j].MaxEntryAddrFound_KSEG1 := False;
  end;

  for j := 0 to AMemTableInfo.SectionCount - 1 do
  begin
    AMemTableInfo.GetSectionEntryAddressesCallback(j, SectionRanges[j].MinAddrSeg1, SectionRanges[j].MinAddrSeg2, SectionRanges[j].MaxAddrSeg1, SectionRanges[j].MaxAddrSeg2);
    AMemTableInfo.GetMemTranslationInfoCallback(j, MemoryTranslationInfos[j]);
  end;



  for j := 0 to AMemTableInfo.SectionCount - 1 do
  begin
    CurrentSectionName := UpperCase(SectionNames[j]); //ROM, RAM, BOOTROM, CFGREG, EBIROM, SQIROM, EEPROM

    if CurrentSectionName <> 'RAM' then
    begin
      for i := 0 to AMemTableInfo.RawMemContentLength - 1 do
      begin
        Entry := AMemTableInfo.GetRawMemContentCallback(i);

        //Two calls / section on PIC32:
        if IsPIC32 then
        begin
          if AMemTableInfo.AddressInMemRangeCallback(j, Entry, AddressOffsets[j].Seg1) then
          begin
            if AllEntryEndpoints[j].MinEntryAddr_KSEG0 > Entry then
            begin
              AllEntryEndpoints[j].MinEntryAddr_KSEG0 := Entry;
              AllEntryEndpoints[j].MinEntryAddrFound_KSEG0 := True;
            end;

            if AllEntryEndpoints[j].MaxEntryAddr_KSEG0 < Entry then
            begin
              AllEntryEndpoints[j].MaxEntryAddr_KSEG0 := Entry;
              AllEntryEndpoints[j].MaxEntryAddrFound_KSEG0 := True;
            end;
          end;

          if AMemTableInfo.AddressInMemRangeCallback(j, Entry, AddressOffsets[j].Seg2) then
          begin
            if AllEntryEndpoints[j].MinEntryAddr_KSEG1 > Entry then
            begin
              AllEntryEndpoints[j].MinEntryAddr_KSEG1 := Entry;
              AllEntryEndpoints[j].MinEntryAddrFound_KSEG1 := True;
            end;

            if AllEntryEndpoints[j].MaxEntryAddr_KSEG1 < Entry then
            begin
              AllEntryEndpoints[j].MaxEntryAddr_KSEG1 := Entry;
              AllEntryEndpoints[j].MaxEntryAddrFound_KSEG1 := True;
            end;
          end;
        end; //IsPIC32
      end; //for i
    end // <>RAM
    else
    begin  //RAM
      for i := 0 to AMemTableInfo.MemContentLength - 1 do
      begin
        Entry := AMemTableInfo.GetMemContentAddressCallback(i);
        EntryEndAddress := Int64(Entry) + Int64(AMemTableInfo.GetMemContentSizeCallback(i)) - 1;

        //Two calls / section on PIC32:
        if IsPIC32 then
        begin
          if AMemTableInfo.AddressInMemRangeCallback(j, Entry, AddressOffsets[j].Seg1) then
          begin
            if AllEntryEndpoints[j].MinEntryAddr_KSEG0 > Entry then
            begin
              AllEntryEndpoints[j].MinEntryAddr_KSEG0 := Entry;
              AllEntryEndpoints[j].MinEntryAddrFound_KSEG0 := True;
            end;

            if AllEntryEndpoints[j].MaxEntryAddr_KSEG0 < EntryEndAddress then
            begin
              AllEntryEndpoints[j].MaxEntryAddr_KSEG0 := EntryEndAddress;
              AllEntryEndpoints[j].MaxEntryAddrFound_KSEG0 := True;
            end;
          end;

          if AMemTableInfo.AddressInMemRangeCallback(j, Entry, AddressOffsets[j].Seg2) then
          begin
            if AllEntryEndpoints[j].MinEntryAddr_KSEG1 > Entry then
            begin
              AllEntryEndpoints[j].MinEntryAddr_KSEG1 := Entry;
              AllEntryEndpoints[j].MinEntryAddrFound_KSEG1 := True;
            end;

            if AllEntryEndpoints[j].MaxEntryAddr_KSEG1 < EntryEndAddress then
            begin
              AllEntryEndpoints[j].MaxEntryAddr_KSEG1 := EntryEndAddress;
              AllEntryEndpoints[j].MaxEntryAddrFound_KSEG1 := True;
            end;
          end;
        end; //IsPIC32
      end; //for i
    end; //RAM
  end; //for j

  for j := 0 to AMemTableInfo.SectionCount - 1 do
  begin
    CurrentSectionName := UpperCase(SectionNames[j]); //ROM, RAM, BOOTROM, CFGREG, EBIROM, SQIROM, EEPROM
    KSeg0 := KSEGNameBySectionName('KSEG0', CurrentSectionName);
    KSeg1 := KSEGNameBySectionName('KSEG1', CurrentSectionName);

    if AllEntryEndpoints[j].MinEntryAddrFound_KSEG0 then
      TempStatistics := TempStatistics + SectionNames[j] + ': First ' + KSeg0 + ' entry: 0x' + IntToHex(AllEntryEndpoints[j].MinEntryAddr_KSEG0, 8) + #13#10
    else
      TempStatistics := TempStatistics + SectionNames[j] + ': First ' + KSeg0 + ' entry: not found' + #13#10;

    if AllEntryEndpoints[j].MaxEntryAddrFound_KSEG0 then
      TempStatistics := TempStatistics + SectionNames[j] + ': Last ' + KSeg0 + ' entry: 0x' + IntToHex(AllEntryEndpoints[j].MaxEntryAddr_KSEG0, 8) + #13#10
    else
      TempStatistics := TempStatistics + SectionNames[j] + ': Last ' + KSeg0 + ' entry: not found' + #13#10;

    if AllEntryEndpoints[j].MinEntryAddrFound_KSEG1 then
      TempStatistics := TempStatistics + SectionNames[j] + ': First ' + KSeg1 + ' entry: 0x' + IntToHex(AllEntryEndpoints[j].MinEntryAddr_KSEG1, 8) + #13#10
    else
      TempStatistics := TempStatistics + SectionNames[j] + ': First ' + KSeg1 + ' entry: not found' + #13#10;

    if AllEntryEndpoints[j].MaxEntryAddrFound_KSEG1 then
      TempStatistics := TempStatistics + SectionNames[j] + ': Last ' + KSeg1 + ' entry: 0x' + IntToHex(AllEntryEndpoints[j].MaxEntryAddr_KSEG1, 8) + #13#10
    else
      TempStatistics := TempStatistics + SectionNames[j] + ': Last ' + KSeg1 + ' entry: not found' + #13#10;

    TempStatistics := TempStatistics + #13#10;
  end;  //for j

  TempStatistics := TempStatistics + #13#10;
  TempStatistics := TempStatistics + 'Free words from beginning of memory to first used word or' + #13#10;
  TempStatistics := TempStatistics + 'free words from last used word to the end of memory:' + #13#10;
  TempStatistics := TempStatistics + #13#10;

  for j := 0 to AMemTableInfo.SectionCount - 1 do
  begin
    CurrentSectionName := UpperCase(SectionNames[j]); //ROM, RAM, BOOTROM, CFGREG, EBIROM, SQIROM, EEPROM
    KSeg0 := KSEGNameBySectionName('KSEG0', CurrentSectionName);
    KSeg1 := KSEGNameBySectionName('KSEG1', CurrentSectionName);

    if AllEntryEndpoints[j].MinEntryAddrFound_KSEG0 then
      TempStatistics := TempStatistics + SectionNames[j] + ' ' + KSeg0 + ': ' + IntToStr((AllEntryEndpoints[j].MinEntryAddr_KSEG0 - AddressOffsets[j].Seg1 - SectionRanges[j].MinAddrSeg1) shr 2) + ' free words from 0x' + IntToHex(SectionRanges[j].MinAddrSeg1 + AddressOffsets[j].Seg1, 8) + ' to first used entry.' + #13#10
    else
      TempStatistics := TempStatistics + SectionNames[j] + ' ' + KSeg0 + ': No ' + KSeg0 + ' entry found. Can''t compute free words.' + #13#10;

    if AllEntryEndpoints[j].MaxEntryAddrFound_KSEG0 then
      TempStatistics := TempStatistics + SectionNames[j] + ' ' + KSeg0 + ': ' + IntToStr((SectionRanges[j].MaxAddrSeg1 + AddressOffsets[j].Seg1 + 1 - AllEntryEndpoints[j].MaxEntryAddr_KSEG0) shr 2) + ' free words from 0x' + IntToHex(AllEntryEndpoints[j].MaxEntryAddr_KSEG0 + 4, 8) + ' to end of ' + SectionNames[j] + ' ' + KSeg0 + '.' + #13#10
    else
      TempStatistics := TempStatistics + SectionNames[j] + ' ' + KSeg0 + ': No ' + KSeg0 + ' entry found. Can''t compute free words.' + #13#10;


    if AllEntryEndpoints[j].MinEntryAddrFound_KSEG1 then
      TempStatistics := TempStatistics + SectionNames[j] + ' ' + KSeg1 + ': ' + IntToStr((AllEntryEndpoints[j].MinEntryAddr_KSEG1 - AddressOffsets[j].Seg2 - SectionRanges[j].MinAddrSeg2) shr 2) + ' free words from 0x' + IntToHex(SectionRanges[j].MinAddrSeg2 + AddressOffsets[j].Seg2, 8) + ' to first used entry.' + #13#10
    else
      TempStatistics := TempStatistics + SectionNames[j] + ' ' + KSeg1 + ': No KSEG1 entry found. Can''t compute free words.' + #13#10;

    if AllEntryEndpoints[j].MaxEntryAddrFound_KSEG1 then
      TempStatistics := TempStatistics + SectionNames[j] + ' ' + KSeg1 + ': ' + IntToStr((SectionRanges[j].MaxAddrSeg2 + AddressOffsets[j].Seg2 + 1 - AllEntryEndpoints[j].MaxEntryAddr_KSEG1) shr 2) + ' free words from 0x' + IntToHex(AllEntryEndpoints[j].MaxEntryAddr_KSEG1 + 4, 8) + ' to end of ' + SectionNames[j] + ' ' + KSeg1 + '.' + #13#10
    else
      TempStatistics := TempStatistics + SectionNames[j] + ' ' + KSeg1 + ': No KSEG1 entry found. Can''t compute free words.' + #13#10;

    TempStatistics := TempStatistics + #13#10;
  end;

  AResultCallback(@TempStatistics[1], Length(TempStatistics));
  TempStatistics := '';
end;


initialization
  FLstContent := TStringList.Create;

finalization
  FreeAndNil(FLstContent);

end.

