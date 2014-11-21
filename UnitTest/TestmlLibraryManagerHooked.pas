unit TestmlLibraryManagerHooked;

interface

uses
  TestFramework,
  Windows,
  Classes,
  SysUtils,
  mlLibrary,
  mlTypes,
  TestConstants;

type
  TestLibraryManagerHooked = class(TTestCase)
  private
    fMemStream: TMemoryStream;
    fEventCalled: Boolean;
    procedure TestEvent(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var aMemStream: TMemoryStream;
        var aFreeStream: Boolean);
    procedure TestEventLoadActionFromMem(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
        aMemStream: TMemoryStream; var aFreeStream: Boolean);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestLoadLibraryValid;
    procedure TestLoadLibraryMemInvalidStream;
    procedure TestLoadLibraryMemEmptyStream;
    procedure TestLoadLibraryTwiceNamed;
    procedure TestLoadLibraryTwiceUnnamed;
    procedure TestGetProcAddressMemValid;
    procedure TestGetProcAddressMemInvalidName;
    procedure TestFindResourceValid;
    procedure TestFreeLibraryMemValid;
    procedure TestFreeLibraryMemInvalidHandle;
    procedure TestFreeLibraryTwiceNamed;
    procedure TestGetModuleFileNameMem;
    procedure TestGetModuleHandleMem;

    procedure TestOnDependencyLoadEvent;

    procedure TestLoadPackage;
  end;

implementation

procedure TestLibraryManagerHooked.TestEvent(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
    aMemStream: TMemoryStream; var aFreeStream: Boolean);
begin
  fEventCalled := true;
end;

procedure TestLibraryManagerHooked.TestEventLoadActionFromMem(const aLibName, aDependentLib: String; var aLoadAction:
    TLoadAction; var aMemStream: TMemoryStream; var aFreeStream: Boolean);
var
  SourceFile: String;
begin
  if aDependentLib = ExtractFileName(BPL_PATH_A) then
    SourceFile := BPL_PATH_A;
  if aDependentLib = ExtractFileName(BPL_PATH_B) then
    SourceFile := BPL_PATH_B;
  if aDependentLib = ExtractFileName(BPL_PATH_C) then
    SourceFile := BPL_PATH_C;
  if SourceFile <> '' then
  begin
    aLoadAction := laMemStream;
    aMemStream := TMemoryStream.Create;
    aMemStream.LoadFromFile(SourceFile);
  end;
end;

procedure TestLibraryManagerHooked.SetUp;
begin
  SetCurrentDir('..\TestDLLs'); // So the test DLL/BPLs can be found

  UnloadAllLibraries;  //VG: Reset the library loader and free the memory
  fMemStream := TMemoryStream.Create;
end;

procedure TestLibraryManagerHooked.TearDown;
begin
  UnloadAllLibraries;  //VG: Reset the library loader and free the memory
  fMemStream.Free;
end;

procedure TestLibraryManagerHooked.TestLoadLibraryValid;
var
  ReturnValue: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  ReturnValue := LoadLibrary(fMemStream);
  CheckNotEquals(0, ReturnValue, 'Library should have been loaded');
end;

procedure TestLibraryManagerHooked.TestLoadLibraryMemInvalidStream;
var
  I: Cardinal;
  ReturnValue: TLibHandle;
begin
  // Try to load from an invalid stream filled with some data
  fMemStream.Size := 100000;
  Randomize;
  for I := 0 to fMemStream.Size - 1 do
    PByte(Cardinal(fMemStream.Memory) + I)^ := Byte(I);

  ExpectedException := EMLLibraryLoadError;
  ReturnValue := LoadLibrary(fMemStream);
  CheckEquals(0, ReturnValue, 'An invalid library should not be loaded');
end;

procedure TestLibraryManagerHooked.TestLoadLibraryMemEmptyStream;
var
  ReturnValue: TLibHandle;
begin
  // Try to load from an empty strem
  fMemStream.Clear;
  ExpectedException := EMLLibraryLoadError;
  ReturnValue := LoadLibrary(fMemStream);
  CheckEquals(0, ReturnValue, 'An empty stream should not be loaded');
end;

procedure TestLibraryManagerHooked.TestLoadLibraryTwiceNamed;
var
  ReturnValue1, ReturnValue2: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  ReturnValue1 := LoadLibrary(fMemStream, DLL_PATH);
  ReturnValue2 := LoadLibrary(fMemStream, DLL_PATH);
  CheckEquals(ReturnValue1, ReturnValue2, 'Library handles should be the same because it is loaded once with RefCount 2');
end;

procedure TestLibraryManagerHooked.TestLoadLibraryTwiceUnnamed;
var
  ReturnValue1, ReturnValue2: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  ReturnValue1 := LoadLibrary(fMemStream);
  ReturnValue2 := LoadLibrary(fMemStream);
  CheckNotEquals(ReturnValue1, ReturnValue2, 'Library handles should be different because no lib names are passed');
end;

procedure TestLibraryManagerHooked.TestGetProcAddressMemValid;
type
  TTestProc = function(A, B: Integer): Integer;
var
  LibHandle: TLibHandle;
  TestProc: TTestProc;
  A, B, C: Integer;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibrary(fMemStream);
  @TestProc := GetProcAddress(LibHandle, TEST_FUNCTION_NAME);
  A := 2; B := 3;
  C := TestProc(A, B);
  CheckEquals(C, A + B);
end;

procedure TestLibraryManagerHooked.TestGetProcAddressMemInvalidName;
var
  LibHandle: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibrary(fMemStream);
  ExpectedException := EMlProcedureError;
  GetProcAddress(LibHandle, 'Some invalid function name');
end;

procedure TestLibraryManagerHooked.TestFindResourceValid;
var
  LibHandle: TLibHandle;
  ResourceFound: HRSRC;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibrary(fMemStream);
  ResourceFound := FindResource(LibHandle, TEST_RES_NAME, TEST_RES_TYPE);
  CheckNotEquals(0, ResourceFound);
end;

procedure TestLibraryManagerHooked.TestFreeLibraryMemValid;
var
  LibHandle: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibrary(fMemStream);
  FreeLibrary(LibHandle);
end;

procedure TestLibraryManagerHooked.TestFreeLibraryMemInvalidHandle;
begin
  ExpectedException := EMlInvalidHandle;
  FreeLibrary(TEST_WRONG_LIB_HANDLE);
end;

procedure TestLibraryManagerHooked.TestFreeLibraryTwiceNamed;
var
  ReturnValue1, ReturnValue2: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  ReturnValue1 := LoadLibrary(fMemStream, DLL_PATH);
  ReturnValue2 := LoadLibrary(fMemStream, DLL_PATH);
  FreeLibrary(ReturnValue1);
  FreeLibrary(ReturnValue2);
  // The RefCount of the library should be 2 so it can be freed twice without raising an exception
end;

procedure TestLibraryManagerHooked.TestGetModuleFileNameMem;
var
  LibHandle: TLibHandle;
  ReturnValue: String;
  ModName: array[0..MAX_PATH + 1] of Char; // No need for a buffer for the full path, we just care if the handle is valid
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibrary(fMemStream, DLL_PATH);
  GetModuleFileName(LibHandle, ModName, Length(ModName));
  ReturnValue := ModName;
  CheckEquals(ReturnValue, ExtractFileName(DLL_PATH));
end;

procedure TestLibraryManagerHooked.TestGetModuleHandleMem;
var
  LibHandle: TLibHandle;
  ReturnValue: TLibHandle;
begin
  fMemStream.LoadFromFile(DLL_PATH);
  LibHandle := LoadLibrary(fMemStream, DLL_PATH);
  ReturnValue := GetModuleHandle(DLL_PATH);
  CheckEquals(ReturnValue, LibHandle);
end;

procedure TestLibraryManagerHooked.TestOnDependencyLoadEvent;
begin
  SetMlOnLoadCallback(TestEvent);
  fEventCalled := false;
  fMemStream.LoadFromFile(BPL_PATH_B);
  LoadLibrary(fMemStream, BPL_PATH_B);
  CheckTrue(fEventCalled, 'The OnDependencyLoad event was not called');
end;

procedure TestLibraryManagerHooked.TestLoadPackage;
var
  TestClass: TPersistentClass;
begin
  fMemStream.LoadFromFile(BPL_PATH_A);
  LoadPackageMem(fMemStream, BPL_PATH_A);
  TestClass := GetClass(TEST_CLASS_NAME_A);
  CheckNotNull(TObject(TestClass), 'The class could not be loaded from the BPL. Check if project is built with Runtime packages');
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestLibraryManagerHooked.Suite);

end.
