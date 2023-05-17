Var
    CurrentSCHLib : ISch_Lib;
    CurrentLib : IPCB_Library;

Function CreateAComponent(Name: String) : IPCB_LibComponent;
Var
    PrimitiveList: TInterfaceList;
    PrimitiveIterator: IPCB_GroupIterator;
    PrimitiveHandle: IPCB_Primitive;
    I:  Integer;

Begin
    // Check if footprint already in library
    Result := CurrentLib.GetComponentByName(Name);
    If Result = Nil Then
    Begin
        // Create New Component
        Result := PCBServer.CreatePCBLibComp;
        Result.Name := Name;
    End
    Else
    Begin
        // Clear existin component
        Try
            // Create List with all primitives on board
            PrimitiveList := TInterfaceList.Create;
            PrimitiveIterator := Result.GroupIterator_Create;
            PrimitiveIterator.AddFilter_ObjectSet(AllObjects);
            PrimitiveHandle := PrimitiveIterator.FirstPCBObject;
            While PrimitiveHandle <> Nil Do
            Begin
                PrimitiveList.Add(PrimitiveHandle);
                PrimitiveHandle := PrimitiveIterator.NextPCBObject;
            End;

            // Delete all primitives
            For I := 0 To PrimitiveList.Count - 1 Do
            Begin
                PrimitiveHandle := PrimitiveList.items[i];
                Result.RemovePCBObject(PrimitiveHandle);
                Result.GraphicallyInvalidate;
            End;

        Finally
            Result.GroupIterator_Destroy(PrimitiveIterator);
            PrimitiveList.Free;
        End;
    End;
End; 

Procedure CreateSMDComponentPad(NewPCBLibComp : IPCB_LibComponent, Name : String, Layer : TLayer, X : Real, Y : Real, OffsetX : Real, OffsetY : Real,
                                TopShape : TShape, TopXSize : Real, TopYSize : Real, Rotation: Real, CRRatio : Real, PMExpansion : Real, SMExpansion : Real,
                                PMFromRules : Boolean, SMFromRules : Boolean);
Var
    NewPad                      : IPCB_Pad2;
    PadCache                    : TPadCache;

Begin
    NewPad := PcbServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    NewPad.HoleSize := MMsToCoord(0);
    NewPad.Layer    := Layer;
    NewPad.TopShape := TopShape;
    if TopShape = eRoundedRectangular then
        NewPad.SetState_StackCRPctOnLayer(eTopLayer, CRRatio);
    NewPad.TopXSize := MMsToCoord(TopXSize);
    NewPad.TopYSize := MMsToCoord(TopYSize);
    NewPad.RotateBy(Rotation);
    NewPad.MoveToXY(MMsToCoord(X), MMsToCoord(Y));
    NewPad.Name := Name;

    Padcache := NewPad.GetState_Cache;
    if (PMExpansion <> 0) or (PMFromRules = False) then
    Begin
        Padcache.PasteMaskExpansionValid   := eCacheManual;
        Padcache.PasteMaskExpansion        := MMsToCoord(PMExpansion);
    End;
    if (SMExpansion <> 0) or (SMFromRules = False) then
    Begin
        Padcache.SolderMaskExpansionValid  := eCacheManual;
        Padcache.SolderMaskExpansion       := MMsToCoord(SMExpansion);
    End;
    NewPad.SetState_Cache              := Padcache;

    NewPCBLibComp.AddPCBObject(NewPad);
    PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewPad.I_ObjectAddress);
End;

Procedure CreateComponentTrack(NewPCBLibComp : IPCB_LibComponent, X1 : Real, Y1 : Real, X2 : Real, Y2 : Real, Layer : TLayer, LineWidth : Real, IsKeepout : Boolean);
Var
    NewTrack                    : IPCB_Track;

Begin
    NewTrack := PcbServer.PCBObjectFactory(eTrackObject,eNoDimension,eCreate_Default);
    NewTrack.X1 := MMsToCoord(X1);
    NewTrack.Y1 := MMsToCoord(Y1);
    NewTrack.X2 := MMsToCoord(X2);
    NewTrack.Y2 := MMsToCoord(Y2);
    NewTrack.Layer := Layer;
    NewTrack.Width := MMsToCoord(LineWidth);
    NewTrack.IsKeepout := IsKeepout;
    NewPCBLibComp.AddPCBObject(NewTrack);
    PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewTrack.I_ObjectAddress);
End;

Procedure CreateComponentArc(NewPCBLibComp : IPCB_LibComponent, CenterX : Real, CenterY : Real, Radius : Real, StartAngle : Real, EndAngle : Real, Layer : TLayer, LineWidth : Real, IsKeepout : Boolean);
Var
    NewArc                      : IPCB_Arc;

Begin
    NewArc := PCBServer.PCBObjectFactory(eArcObject,eNoDimension,eCreate_Default);
    NewArc.XCenter := MMsToCoord(CenterX);
    NewArc.YCenter := MMsToCoord(CenterY);
    NewArc.Radius := MMsToCoord(Radius);
    NewArc.StartAngle := StartAngle;
    NewArc.EndAngle := EndAngle;
    NewArc.Layer := Layer;
    NewArc.LineWidth := MMsToCoord(LineWidth);
    NewArc.IsKeepout := IsKeepout;
    NewPCBLibComp.AddPCBObject(NewArc);
    PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewArc.I_ObjectAddress);
End;

Function ReadStringFromIniFile(Section: String, Name: String, FilePath: String, IfEmpty: String) : String;
Var
    IniFile                     : TIniFile;

Begin
    result := IfEmpty;
    If FileExists(FilePath) Then
    Begin
        Try
            IniFile := TIniFile.Create(FilePath);

            Result := IniFile.ReadString(Section, Name, IfEmpty);
        Finally
            Inifile.Free;
        End;
    End;
End;

Procedure EnableMechanicalLayers(Zero : Integer);
Var
    Board                       : IPCB_Board;
    MajorADVersion              : Integer;

Begin
End;

Procedure DeleteFootprint(Name : String);
var
    CurrentLib      : IPCB_Library;
    del_list        : TInterfaceList;
    I               :  Integer;
    S_temp          : TString;
    Footprint       : IPCB_LibComponent;
    FootprintIterator : Integer;

Begin
    // ShowMessage('Script running');
    CurrentLib       := PCBServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('This is not a PCB library document');
        Exit;
    End;

    // store selected footprints in a TInterfacelist that are to be deleted later...
    del_list := TInterfaceList.Create;

    // For each page of library Is a footprint
    FootprintIterator := CurrentLib.LibraryIterator_Create;
    FootprintIterator.SetState_FilterAll;

    // Within each page, fetch primitives of the footprint
    // A footprint Is a IPCB_LibComponent inherited from
    // IPCB_Group which Is a container object storing primitives.
    Footprint := FootprintIterator.FirstPCBObject; // IPCB_LibComponent

    while (Footprint <> Nil) Do
    begin
        S_temp :=Footprint.Name;

        // check for specific footprint, to delete them before (0=equal string)
        If Not (CompareText(S_temp, Name)) Then
        begin
            del_list.Add(Footprint);
            //ShowMessage('selected footprint ' + Footprint.Name);
        end;
        Footprint := FootprintIterator.NextPCBObject;
    end;

    CurrentLib.LibraryIterator_Destroy(FootprintIterator);

    Try
        PCBServer.PreProcess;
        For I := 0 To del_list.Count - 1 Do
        Begin
            Footprint := del_list.items[i];
            // ShowMessage('deleted footprint ' + Footprint.Name);
            CurrentLib.RemoveComponent(Footprint);
        End;
    Finally
        PCBServer.PostProcess;
        del_list.Free;
    End;
End;

Procedure CreateComponentQFP144P50_2200X2200X160L60X22(Zero : integer);
Var
    NewPCBLibComp               : IPCB_LibComponent;
    NewPad                      : IPCB_Pad2;
    NewRegion                   : IPCB_Region;
    NewContour                  : IPCB_Contour;
    STEPmodel                   : IPCB_ComponentBody;
    Model                       : IPCB_Model;
    TextObj                     : IPCB_Text;

Begin
    Try
        PCBServer.PreProcess;

        EnableMechanicalLayers(0);

        NewPcbLibComp := CreateAComponent('QFP144P50_2200X2200X160L60X22');
        NewPcbLibComp.Name := 'QFP144P50_2200X2200X160L60X22';
        NewPCBLibComp.Description := 'Quad Flat Pack (QFP), 0.50 mm pitch;  square, 36 pin X 36 pin, 20.00 mm L X 20.00 mm W X 1.60 mm H body';
        NewPCBLibComp.Height := MMsToCoord(1.6);

        CreateSMDComponentPad(NewPCBLibComp, '1', eTopLayer, -8.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '2', eTopLayer, -8.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '3', eTopLayer, -7.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '4', eTopLayer, -7.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '5', eTopLayer, -6.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '6', eTopLayer, -6.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '7', eTopLayer, -5.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '8', eTopLayer, -5.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '9', eTopLayer, -4.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '10', eTopLayer, -4.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '11', eTopLayer, -3.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '12', eTopLayer, -3.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '13', eTopLayer, -2.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '14', eTopLayer, -2.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '15', eTopLayer, -1.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '16', eTopLayer, -1.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '17', eTopLayer, -0.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '18', eTopLayer, -0.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '19', eTopLayer, 0.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '20', eTopLayer, 0.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '21', eTopLayer, 1.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '22', eTopLayer, 1.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '23', eTopLayer, 2.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '24', eTopLayer, 2.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '25', eTopLayer, 3.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '26', eTopLayer, 3.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '27', eTopLayer, 4.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '28', eTopLayer, 4.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '29', eTopLayer, 5.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '30', eTopLayer, 5.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '31', eTopLayer, 6.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '32', eTopLayer, 6.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '33', eTopLayer, 7.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '34', eTopLayer, 7.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '35', eTopLayer, 8.25, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '36', eTopLayer, 8.75, -10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 270, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '37', eTopLayer, 10.625, -8.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '38', eTopLayer, 10.625, -8.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '39', eTopLayer, 10.625, -7.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '40', eTopLayer, 10.625, -7.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '41', eTopLayer, 10.625, -6.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '42', eTopLayer, 10.625, -6.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '43', eTopLayer, 10.625, -5.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '44', eTopLayer, 10.625, -5.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '45', eTopLayer, 10.625, -4.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '46', eTopLayer, 10.625, -4.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '47', eTopLayer, 10.625, -3.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '48', eTopLayer, 10.625, -3.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '49', eTopLayer, 10.625, -2.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '50', eTopLayer, 10.625, -2.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '51', eTopLayer, 10.625, -1.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '52', eTopLayer, 10.625, -1.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '53', eTopLayer, 10.625, -0.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '54', eTopLayer, 10.625, -0.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '55', eTopLayer, 10.625, 0.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '56', eTopLayer, 10.625, 0.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '57', eTopLayer, 10.625, 1.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '58', eTopLayer, 10.625, 1.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '59', eTopLayer, 10.625, 2.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '60', eTopLayer, 10.625, 2.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '61', eTopLayer, 10.625, 3.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '62', eTopLayer, 10.625, 3.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '63', eTopLayer, 10.625, 4.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '64', eTopLayer, 10.625, 4.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '65', eTopLayer, 10.625, 5.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '66', eTopLayer, 10.625, 5.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '67', eTopLayer, 10.625, 6.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '68', eTopLayer, 10.625, 6.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '69', eTopLayer, 10.625, 7.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '70', eTopLayer, 10.625, 7.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '71', eTopLayer, 10.625, 8.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '72', eTopLayer, 10.625, 8.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 0, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '73', eTopLayer, 8.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '74', eTopLayer, 8.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '75', eTopLayer, 7.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '76', eTopLayer, 7.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '77', eTopLayer, 6.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '78', eTopLayer, 6.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '79', eTopLayer, 5.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '80', eTopLayer, 5.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '81', eTopLayer, 4.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '82', eTopLayer, 4.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '83', eTopLayer, 3.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '84', eTopLayer, 3.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '85', eTopLayer, 2.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '86', eTopLayer, 2.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '87', eTopLayer, 1.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '88', eTopLayer, 1.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '89', eTopLayer, 0.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '90', eTopLayer, 0.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '91', eTopLayer, -0.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '92', eTopLayer, -0.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '93', eTopLayer, -1.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '94', eTopLayer, -1.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '95', eTopLayer, -2.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '96', eTopLayer, -2.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '97', eTopLayer, -3.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '98', eTopLayer, -3.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '99', eTopLayer, -4.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '100', eTopLayer, -4.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '101', eTopLayer, -5.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '102', eTopLayer, -5.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '103', eTopLayer, -6.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '104', eTopLayer, -6.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '105', eTopLayer, -7.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '106', eTopLayer, -7.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '107', eTopLayer, -8.25, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '108', eTopLayer, -8.75, 10.625, 0, 0, eRoundedRectangular, 1.35, 0.35, 90, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '109', eTopLayer, -10.625, 8.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '110', eTopLayer, -10.625, 8.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '111', eTopLayer, -10.625, 7.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '112', eTopLayer, -10.625, 7.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '113', eTopLayer, -10.625, 6.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '114', eTopLayer, -10.625, 6.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '115', eTopLayer, -10.625, 5.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '116', eTopLayer, -10.625, 5.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '117', eTopLayer, -10.625, 4.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '118', eTopLayer, -10.625, 4.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '119', eTopLayer, -10.625, 3.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '120', eTopLayer, -10.625, 3.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '121', eTopLayer, -10.625, 2.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '122', eTopLayer, -10.625, 2.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '123', eTopLayer, -10.625, 1.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '124', eTopLayer, -10.625, 1.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '125', eTopLayer, -10.625, 0.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '126', eTopLayer, -10.625, 0.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '127', eTopLayer, -10.625, -0.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '128', eTopLayer, -10.625, -0.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '129', eTopLayer, -10.625, -1.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '130', eTopLayer, -10.625, -1.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '131', eTopLayer, -10.625, -2.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '132', eTopLayer, -10.625, -2.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '133', eTopLayer, -10.625, -3.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '134', eTopLayer, -10.625, -3.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '135', eTopLayer, -10.625, -4.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '136', eTopLayer, -10.625, -4.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '137', eTopLayer, -10.625, -5.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '138', eTopLayer, -10.625, -5.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '139', eTopLayer, -10.625, -6.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '140', eTopLayer, -10.625, -6.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '141', eTopLayer, -10.625, -7.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '142', eTopLayer, -10.625, -7.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '143', eTopLayer, -10.625, -8.25, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '144', eTopLayer, -10.625, -8.75, 0, 0, eRoundedRectangular, 1.35, 0.35, 180, 42.86, 0, 0, True, True);

        CreateComponentTrack(NewPCBLibComp, -8.86, -10.4, -8.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.64, -10.4, -8.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.64, -11, -8.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.86, -11, -8.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.36, -10.4, -8.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.14, -10.4, -8.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.14, -11, -8.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.36, -11, -8.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.86, -10.4, -7.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.64, -10.4, -7.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.64, -11, -7.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.86, -11, -7.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.36, -10.4, -7.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.14, -10.4, -7.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.14, -11, -7.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.36, -11, -7.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.86, -10.4, -6.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.64, -10.4, -6.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.64, -11, -6.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.86, -11, -6.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.36, -10.4, -6.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.14, -10.4, -6.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.14, -11, -6.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.36, -11, -6.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.86, -10.4, -5.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.64, -10.4, -5.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.64, -11, -5.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.86, -11, -5.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.36, -10.4, -5.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.14, -10.4, -5.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.14, -11, -5.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.36, -11, -5.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.86, -10.4, -4.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.64, -10.4, -4.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.64, -11, -4.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.86, -11, -4.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.36, -10.4, -4.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.14, -10.4, -4.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.14, -11, -4.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.36, -11, -4.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.86, -10.4, -3.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.64, -10.4, -3.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.64, -11, -3.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.86, -11, -3.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.36, -10.4, -3.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.14, -10.4, -3.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.14, -11, -3.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.36, -11, -3.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.86, -10.4, -2.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.64, -10.4, -2.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.64, -11, -2.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.86, -11, -2.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.36, -10.4, -2.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.14, -10.4, -2.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.14, -11, -2.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.36, -11, -2.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.86, -10.4, -1.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.64, -10.4, -1.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.64, -11, -1.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.86, -11, -1.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.36, -10.4, -1.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.14, -10.4, -1.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.14, -11, -1.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.36, -11, -1.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.86, -10.4, -0.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.64, -10.4, -0.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.64, -11, -0.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.86, -11, -0.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.36, -10.4, -0.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.14, -10.4, -0.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.14, -11, -0.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.36, -11, -0.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.14, -10.4, 0.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.36, -10.4, 0.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.36, -11, 0.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.14, -11, 0.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.64, -10.4, 0.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.86, -10.4, 0.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.86, -11, 0.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.64, -11, 0.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.14, -10.4, 1.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.36, -10.4, 1.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.36, -11, 1.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.14, -11, 1.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.64, -10.4, 1.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.86, -10.4, 1.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.86, -11, 1.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.64, -11, 1.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.14, -10.4, 2.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.36, -10.4, 2.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.36, -11, 2.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.14, -11, 2.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.64, -10.4, 2.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.86, -10.4, 2.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.86, -11, 2.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.64, -11, 2.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.14, -10.4, 3.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.36, -10.4, 3.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.36, -11, 3.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.14, -11, 3.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.64, -10.4, 3.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.86, -10.4, 3.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.86, -11, 3.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.64, -11, 3.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.14, -10.4, 4.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.36, -10.4, 4.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.36, -11, 4.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.14, -11, 4.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.64, -10.4, 4.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.86, -10.4, 4.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.86, -11, 4.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.64, -11, 4.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.14, -10.4, 5.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.36, -10.4, 5.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.36, -11, 5.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.14, -11, 5.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.64, -10.4, 5.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.86, -10.4, 5.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.86, -11, 5.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.64, -11, 5.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.14, -10.4, 6.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.36, -10.4, 6.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.36, -11, 6.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.14, -11, 6.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.64, -10.4, 6.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.86, -10.4, 6.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.86, -11, 6.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.64, -11, 6.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.14, -10.4, 7.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.36, -10.4, 7.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.36, -11, 7.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.14, -11, 7.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.64, -10.4, 7.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.86, -10.4, 7.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.86, -11, 7.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.64, -11, 7.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.14, -10.4, 8.36, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.36, -10.4, 8.36, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.36, -11, 8.14, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.14, -11, 8.14, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.64, -10.4, 8.86, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.86, -10.4, 8.86, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.86, -11, 8.64, -11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.64, -11, 8.64, -10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -8.86, 10.4, -8.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -8.64, 11, -8.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -8.64, 11, -8.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -8.86, 10.4, -8.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -8.36, 10.4, -8.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -8.14, 11, -8.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -8.14, 11, -8.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -8.36, 10.4, -8.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -7.86, 10.4, -7.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -7.64, 11, -7.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -7.64, 11, -7.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -7.86, 10.4, -7.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -7.36, 10.4, -7.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -7.14, 11, -7.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -7.14, 11, -7.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -7.36, 10.4, -7.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -6.86, 10.4, -6.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -6.64, 11, -6.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -6.64, 11, -6.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -6.86, 10.4, -6.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -6.36, 10.4, -6.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -6.14, 11, -6.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -6.14, 11, -6.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -6.36, 10.4, -6.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -5.86, 10.4, -5.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -5.64, 11, -5.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -5.64, 11, -5.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -5.86, 10.4, -5.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -5.36, 10.4, -5.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -5.14, 11, -5.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -5.14, 11, -5.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -5.36, 10.4, -5.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -4.86, 10.4, -4.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -4.64, 11, -4.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -4.64, 11, -4.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -4.86, 10.4, -4.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -4.36, 10.4, -4.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -4.14, 11, -4.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -4.14, 11, -4.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -4.36, 10.4, -4.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -3.86, 10.4, -3.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -3.64, 11, -3.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -3.64, 11, -3.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -3.86, 10.4, -3.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -3.36, 10.4, -3.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -3.14, 11, -3.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -3.14, 11, -3.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -3.36, 10.4, -3.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -2.86, 10.4, -2.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -2.64, 11, -2.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -2.64, 11, -2.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -2.86, 10.4, -2.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -2.36, 10.4, -2.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -2.14, 11, -2.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -2.14, 11, -2.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -2.36, 10.4, -2.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -1.86, 10.4, -1.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -1.64, 11, -1.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -1.64, 11, -1.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -1.86, 10.4, -1.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -1.36, 10.4, -1.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -1.14, 11, -1.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -1.14, 11, -1.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -1.36, 10.4, -1.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -0.86, 10.4, -0.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -0.64, 11, -0.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -0.64, 11, -0.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -0.86, 10.4, -0.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -0.36, 10.4, -0.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, -0.14, 11, -0.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -0.14, 11, -0.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, -0.36, 10.4, -0.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 0.14, 10.4, 0.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 0.36, 11, 0.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 0.36, 11, 0.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 0.14, 10.4, 0.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 0.64, 10.4, 0.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 0.86, 11, 0.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 0.86, 11, 0.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 0.64, 10.4, 0.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 1.14, 10.4, 1.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 1.36, 11, 1.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 1.36, 11, 1.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 1.14, 10.4, 1.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 1.64, 10.4, 1.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 1.86, 11, 1.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 1.86, 11, 1.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 1.64, 10.4, 1.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 2.14, 10.4, 2.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 2.36, 11, 2.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 2.36, 11, 2.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 2.14, 10.4, 2.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 2.64, 10.4, 2.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 2.86, 11, 2.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 2.86, 11, 2.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 2.64, 10.4, 2.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 3.14, 10.4, 3.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 3.36, 11, 3.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 3.36, 11, 3.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 3.14, 10.4, 3.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 3.64, 10.4, 3.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 3.86, 11, 3.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 3.86, 11, 3.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 3.64, 10.4, 3.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 4.14, 10.4, 4.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 4.36, 11, 4.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 4.36, 11, 4.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 4.14, 10.4, 4.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 4.64, 10.4, 4.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 4.86, 11, 4.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 4.86, 11, 4.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 4.64, 10.4, 4.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 5.14, 10.4, 5.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 5.36, 11, 5.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 5.36, 11, 5.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 5.14, 10.4, 5.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 5.64, 10.4, 5.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 5.86, 11, 5.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 5.86, 11, 5.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 5.64, 10.4, 5.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 6.14, 10.4, 6.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 6.36, 11, 6.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 6.36, 11, 6.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 6.14, 10.4, 6.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 6.64, 10.4, 6.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 6.86, 11, 6.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 6.86, 11, 6.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 6.64, 10.4, 6.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 7.14, 10.4, 7.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 7.36, 11, 7.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 7.36, 11, 7.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 7.14, 10.4, 7.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 7.64, 10.4, 7.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 7.86, 11, 7.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 7.86, 11, 7.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 7.64, 10.4, 7.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 8.14, 10.4, 8.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 8.36, 11, 8.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 8.36, 11, 8.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 8.14, 10.4, 8.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 8.64, 10.4, 8.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10.4, 8.86, 11, 8.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 8.86, 11, 8.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 11, 8.64, 10.4, 8.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.86, 10.4, 8.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.64, 10.4, 8.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.64, 11, 8.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.86, 11, 8.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.36, 10.4, 8.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.14, 10.4, 8.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.14, 11, 8.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8.36, 11, 8.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.86, 10.4, 7.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.64, 10.4, 7.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.64, 11, 7.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.86, 11, 7.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.36, 10.4, 7.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.14, 10.4, 7.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.14, 11, 7.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7.36, 11, 7.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.86, 10.4, 6.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.64, 10.4, 6.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.64, 11, 6.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.86, 11, 6.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.36, 10.4, 6.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.14, 10.4, 6.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.14, 11, 6.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6.36, 11, 6.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.86, 10.4, 5.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.64, 10.4, 5.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.64, 11, 5.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.86, 11, 5.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.36, 10.4, 5.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.14, 10.4, 5.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.14, 11, 5.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.36, 11, 5.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.86, 10.4, 4.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.64, 10.4, 4.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.64, 11, 4.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.86, 11, 4.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.36, 10.4, 4.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.14, 10.4, 4.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.14, 11, 4.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 4.36, 11, 4.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.86, 10.4, 3.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.64, 10.4, 3.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.64, 11, 3.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.86, 11, 3.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.36, 10.4, 3.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.14, 10.4, 3.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.14, 11, 3.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.36, 11, 3.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.86, 10.4, 2.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.64, 10.4, 2.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.64, 11, 2.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.86, 11, 2.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.36, 10.4, 2.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.14, 10.4, 2.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.14, 11, 2.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.36, 11, 2.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.86, 10.4, 1.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.64, 10.4, 1.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.64, 11, 1.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.86, 11, 1.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.36, 10.4, 1.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.14, 10.4, 1.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.14, 11, 1.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.36, 11, 1.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.86, 10.4, 0.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.64, 10.4, 0.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.64, 11, 0.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.86, 11, 0.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.36, 10.4, 0.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.14, 10.4, 0.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.14, 11, 0.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.36, 11, 0.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.14, 10.4, -0.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.36, 10.4, -0.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.36, 11, -0.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.14, 11, -0.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.64, 10.4, -0.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.86, 10.4, -0.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.86, 11, -0.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.64, 11, -0.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.14, 10.4, -1.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.36, 10.4, -1.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.36, 11, -1.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.14, 11, -1.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.64, 10.4, -1.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.86, 10.4, -1.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.86, 11, -1.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.64, 11, -1.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.14, 10.4, -2.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.36, 10.4, -2.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.36, 11, -2.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.14, 11, -2.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.64, 10.4, -2.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.86, 10.4, -2.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.86, 11, -2.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.64, 11, -2.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.14, 10.4, -3.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.36, 10.4, -3.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.36, 11, -3.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.14, 11, -3.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.64, 10.4, -3.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.86, 10.4, -3.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.86, 11, -3.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.64, 11, -3.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.14, 10.4, -4.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.36, 10.4, -4.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.36, 11, -4.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.14, 11, -4.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.64, 10.4, -4.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.86, 10.4, -4.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.86, 11, -4.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -4.64, 11, -4.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.14, 10.4, -5.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.36, 10.4, -5.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.36, 11, -5.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.14, 11, -5.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.64, 10.4, -5.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.86, 10.4, -5.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.86, 11, -5.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.64, 11, -5.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.14, 10.4, -6.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.36, 10.4, -6.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.36, 11, -6.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.14, 11, -6.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.64, 10.4, -6.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.86, 10.4, -6.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.86, 11, -6.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6.64, 11, -6.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.14, 10.4, -7.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.36, 10.4, -7.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.36, 11, -7.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.14, 11, -7.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.64, 10.4, -7.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.86, 10.4, -7.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.86, 11, -7.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7.64, 11, -7.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.14, 10.4, -8.36, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.36, 10.4, -8.36, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.36, 11, -8.14, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.14, 11, -8.14, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.64, 10.4, -8.86, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.86, 10.4, -8.86, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.86, 11, -8.64, 11, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8.64, 11, -8.64, 10.4, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 8.86, -10.4, 8.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 8.64, -11, 8.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 8.64, -11, 8.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 8.86, -10.4, 8.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 8.36, -10.4, 8.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 8.14, -11, 8.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 8.14, -11, 8.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 8.36, -10.4, 8.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 7.86, -10.4, 7.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 7.64, -11, 7.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 7.64, -11, 7.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 7.86, -10.4, 7.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 7.36, -10.4, 7.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 7.14, -11, 7.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 7.14, -11, 7.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 7.36, -10.4, 7.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 6.86, -10.4, 6.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 6.64, -11, 6.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 6.64, -11, 6.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 6.86, -10.4, 6.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 6.36, -10.4, 6.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 6.14, -11, 6.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 6.14, -11, 6.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 6.36, -10.4, 6.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 5.86, -10.4, 5.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 5.64, -11, 5.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 5.64, -11, 5.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 5.86, -10.4, 5.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 5.36, -10.4, 5.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 5.14, -11, 5.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 5.14, -11, 5.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 5.36, -10.4, 5.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 4.86, -10.4, 4.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 4.64, -11, 4.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 4.64, -11, 4.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 4.86, -10.4, 4.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 4.36, -10.4, 4.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 4.14, -11, 4.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 4.14, -11, 4.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 4.36, -10.4, 4.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 3.86, -10.4, 3.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 3.64, -11, 3.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 3.64, -11, 3.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 3.86, -10.4, 3.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 3.36, -10.4, 3.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 3.14, -11, 3.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 3.14, -11, 3.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 3.36, -10.4, 3.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 2.86, -10.4, 2.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 2.64, -11, 2.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 2.64, -11, 2.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 2.86, -10.4, 2.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 2.36, -10.4, 2.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 2.14, -11, 2.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 2.14, -11, 2.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 2.36, -10.4, 2.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 1.86, -10.4, 1.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 1.64, -11, 1.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 1.64, -11, 1.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 1.86, -10.4, 1.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 1.36, -10.4, 1.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 1.14, -11, 1.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 1.14, -11, 1.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 1.36, -10.4, 1.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 0.86, -10.4, 0.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 0.64, -11, 0.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 0.64, -11, 0.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 0.86, -10.4, 0.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 0.36, -10.4, 0.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, 0.14, -11, 0.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 0.14, -11, 0.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, 0.36, -10.4, 0.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -0.14, -10.4, -0.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -0.36, -11, -0.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -0.36, -11, -0.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -0.14, -10.4, -0.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -0.64, -10.4, -0.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -0.86, -11, -0.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -0.86, -11, -0.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -0.64, -10.4, -0.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -1.14, -10.4, -1.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -1.36, -11, -1.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -1.36, -11, -1.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -1.14, -10.4, -1.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -1.64, -10.4, -1.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -1.86, -11, -1.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -1.86, -11, -1.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -1.64, -10.4, -1.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -2.14, -10.4, -2.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -2.36, -11, -2.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -2.36, -11, -2.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -2.14, -10.4, -2.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -2.64, -10.4, -2.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -2.86, -11, -2.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -2.86, -11, -2.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -2.64, -10.4, -2.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -3.14, -10.4, -3.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -3.36, -11, -3.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -3.36, -11, -3.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -3.14, -10.4, -3.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -3.64, -10.4, -3.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -3.86, -11, -3.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -3.86, -11, -3.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -3.64, -10.4, -3.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -4.14, -10.4, -4.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -4.36, -11, -4.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -4.36, -11, -4.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -4.14, -10.4, -4.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -4.64, -10.4, -4.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -4.86, -11, -4.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -4.86, -11, -4.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -4.64, -10.4, -4.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -5.14, -10.4, -5.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -5.36, -11, -5.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -5.36, -11, -5.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -5.14, -10.4, -5.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -5.64, -10.4, -5.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -5.86, -11, -5.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -5.86, -11, -5.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -5.64, -10.4, -5.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -6.14, -10.4, -6.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -6.36, -11, -6.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -6.36, -11, -6.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -6.14, -10.4, -6.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -6.64, -10.4, -6.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -6.86, -11, -6.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -6.86, -11, -6.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -6.64, -10.4, -6.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -7.14, -10.4, -7.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -7.36, -11, -7.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -7.36, -11, -7.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -7.14, -10.4, -7.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -7.64, -10.4, -7.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -7.86, -11, -7.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -7.86, -11, -7.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -7.64, -10.4, -7.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -8.14, -10.4, -8.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -8.36, -11, -8.36, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -8.36, -11, -8.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -8.14, -10.4, -8.14, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -8.64, -10.4, -8.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10.4, -8.86, -11, -8.86, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -8.86, -11, -8.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -11, -8.64, -10.4, -8.64, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10, -10, -10, 10, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10, 10, 10, 10, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10, 10, 10, -10, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 10, -10, -10, -10, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -10, -10, -10, 10, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -10, 10, 10, 10, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 10, 10, 10, -10, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 10, -10, -10, -10, eMechanical3, 0.12, False);
        CreateComponentArc(NewPCBLibComp, 0, 0, 0.25, 0, 360, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0.35, 0, -0.35, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -0.35, 0, 0.35, 0, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -9.105, -10, -10, -10, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -10, -10, -10, -9.105, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 9.105, -10, 10, -10, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 10, -10, 10, -9.105, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 9.105, 10, 10, 10, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 10, 10, 10, 9.105, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -9.105, 10, -10, 10, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -10, 10, -10, 9.105, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 10.2, -10.2, 10.2, -9.125, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 10.2, -9.125, 11.5, -9.125, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 11.5, -9.125, 11.5, 9.125, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 11.5, 9.125, 10.2, 9.125, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 10.2, 9.125, 10.2, 10.2, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 10.2, 10.2, 9.125, 10.2, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 9.125, 10.2, 9.125, 11.5, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 9.125, 11.5, -9.125, 11.5, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -9.125, 11.5, -9.125, 10.2, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -9.125, 10.2, -10.2, 10.2, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -10.2, 10.2, -10.2, 9.125, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -10.2, 9.125, -11.5, 9.125, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -11.5, 9.125, -11.5, -9.125, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -11.5, -9.125, -10.2, -9.125, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -10.2, -9.125, -10.2, -10.2, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -10.2, -10.2, -9.125, -10.2, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -9.125, -10.2, -9.125, -11.5, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -9.125, -11.5, 9.125, -11.5, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 9.125, -11.5, 9.125, -10.2, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 9.125, -10.2, 10.2, -10.2, eMechanical7, 0.05, False);

        STEPmodel := PcbServer.PCBObjectFactory(eComponentBodyObject, eNoDimension, eCreate_Default);
        Model := STEPmodel.ModelFactory_FromFilename('C:\Users\Korisnik\Desktop\FESB Racing\Components\Script\QFP144P50_2200X2200X160L60X22.STEP', false);
        STEPModel.Layer := eMechanical1;
        STEPmodel.Model := Model;
        STEPmodel.SetState_Identifier('QFP144P50_2200X2200X160L60X22');
        NewPCBLibComp.AddPCBObject(STEPmodel);

        CurrentLib.RegisterComponent(NewPCBLibComp);
        CurrentLib.CurrentComponent := NewPcbLibComp;
    Finally
        PCBServer.PostProcess;
    End;

    CurrentLib.Board.ViewManager_UpdateLayerTabs;
    CurrentLib.Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=All' , 255, Client.CurrentView)
End;

Procedure CreateAPCBLibrary(Zero : integer);
Var
    View     : IServerDocumentView;
    Document : IServerDocument;
    TempPCBLibComp : IPCB_LibComponent;

Begin
    If PCBServer = Nil Then
    Begin
        ShowMessage('No PCBServer present. This script inserts a footprint into an existing PCB Library that has the current focus.');
        Exit;
    End;

    CurrentLib := PcbServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('You must have focus on a PCB Library in order for this script to run.');
        Exit;
    End;

    View := Client.GetCurrentView;
    Document := View.OwnerDocument;
    Document.Modified := True;

    // Create And focus a temporary component While we delete items (BugCrunch #10165)
    TempPCBLibComp := PCBServer.CreatePCBLibComp;
    TempPcbLibComp.Name := '___TemporaryComponent___';
    CurrentLib.RegisterComponent(TempPCBLibComp);
    CurrentLib.CurrentComponent := TempPcbLibComp;
    CurrentLib.Board.ViewManager_FullUpdate;

    CreateComponentQFP144P50_2200X2200X160L60X22(0);

    // Delete Temporary Footprint And re-focus
    CurrentLib.RemoveComponent(TempPCBLibComp);
    CurrentLib.Board.ViewManager_UpdateLayerTabs;
    CurrentLib.Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=All', 255, Client.CurrentView);

    DeleteFootprint('PCBCOMPONENT_1');  // Randy Added - Delete PCBCOMPONENT_1

End;

Procedure CreateALibrary;
Begin
    Screen.Cursor := crHourGlass;

    CreateAPCBLibrary(0);

    Screen.Cursor := crArrow;
End;

End.
