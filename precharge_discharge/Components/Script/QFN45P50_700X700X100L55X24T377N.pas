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

Procedure CreateComponentQFN45P50_700X700X100L55X24T377N(Zero : integer);
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

        NewPcbLibComp := CreateAComponent('QFN45P50_700X700X100L55X24T377N');
        NewPcbLibComp.Name := 'QFN45P50_700X700X100L55X24T377N';
        NewPCBLibComp.Description := 'Quad Flat No-Lead (QFN) with Thermal Tab, 0.50 mm pitch;  square, 11 pin X 11 pin, 7.00 mm L X 7.00 mm W X 1.00 mm H Body';
        NewPCBLibComp.Height := MMsToCoord(1);

        CreateSMDComponentPad(NewPCBLibComp, '1', eTopLayer, -2.5, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '2', eTopLayer, -2, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '3', eTopLayer, -1.5, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '4', eTopLayer, -1, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '5', eTopLayer, -0.5, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '6', eTopLayer, 0, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '7', eTopLayer, 0.5, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '8', eTopLayer, 1, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '9', eTopLayer, 1.5, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '10', eTopLayer, 2, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '11', eTopLayer, 2.5, -3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 270, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '12', eTopLayer, 3.28, -2.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '13', eTopLayer, 3.28, -2, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '14', eTopLayer, 3.28, -1.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '15', eTopLayer, 3.28, -1, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '16', eTopLayer, 3.28, -0.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '17', eTopLayer, 3.28, 0, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '18', eTopLayer, 3.28, 0.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '19', eTopLayer, 3.28, 1, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '20', eTopLayer, 3.28, 1.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '21', eTopLayer, 3.28, 2, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '22', eTopLayer, 3.28, 2.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 0, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '23', eTopLayer, 2.5, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '24', eTopLayer, 2, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '25', eTopLayer, 1.5, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '26', eTopLayer, 1, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '27', eTopLayer, 0.5, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '28', eTopLayer, 0, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '29', eTopLayer, -0.5, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '30', eTopLayer, -1, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '31', eTopLayer, -1.5, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '32', eTopLayer, -2, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '33', eTopLayer, -2.5, 3.28, 0, 0, eRoundedRectangular, 0.953, 0.264, 90, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '34', eTopLayer, -3.28, 2.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '35', eTopLayer, -3.28, 2, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '36', eTopLayer, -3.28, 1.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '37', eTopLayer, -3.28, 1, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '38', eTopLayer, -3.28, 0.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '39', eTopLayer, -3.28, 0, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '40', eTopLayer, -3.28, -0.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '41', eTopLayer, -3.28, -1, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '42', eTopLayer, -3.28, -1.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '43', eTopLayer, -3.28, -2, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '44', eTopLayer, -3.28, -2.5, 0, 0, eRoundedRectangular, 0.953, 0.264, 180, 50, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '45', eTopLayer, 0, 0, 0, 0, eRectangular, 3.275, 3.275, 90, 0, -3.275, -3.275, True, True);

        NewRegion := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
        NewContour := PCBServer.PCBContourFactory;
        NewContour.AddPoint(MMsToCoord(1.8875), MMsToCoord(-1.8875));
        NewContour.AddPoint(MMsToCoord(-1.6375), MMsToCoord(-1.8875));
        NewContour.AddPoint(MMsToCoord(-1.8875), MMsToCoord(-1.6375));
        NewContour.AddPoint(MMsToCoord(-1.8875), MMsToCoord(1.8875));
        NewContour.AddPoint(MMsToCoord(1.8875), MMsToCoord(1.8875));
        NewContour.AddPoint(MMsToCoord(1.8875), MMsToCoord(-1.8875));
        NewRegion.SetOutlineContour(NewContour);
        NewRegion.Layer := eTopLayer;
        NewPCBLibComp.AddPCBObject(NewRegion);

        NewRegion := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
        NewContour := PCBServer.PCBContourFactory;
        NewContour.AddPoint(MMsToCoord(1.8875), MMsToCoord(-1.8875));
        NewContour.AddPoint(MMsToCoord(-1.6375), MMsToCoord(-1.8875));
        NewContour.AddPoint(MMsToCoord(-1.8875), MMsToCoord(-1.6375));
        NewContour.AddPoint(MMsToCoord(-1.8875), MMsToCoord(1.8875));
        NewContour.AddPoint(MMsToCoord(1.8875), MMsToCoord(1.8875));
        NewContour.AddPoint(MMsToCoord(1.8875), MMsToCoord(-1.8875));
        NewRegion.SetOutlineContour(NewContour);
        NewRegion.Layer := eTopSolder;
        NewPCBLibComp.AddPCBObject(NewRegion);


        NewRegion := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
        NewContour := PCBServer.PCBContourFactory;
        NewContour.AddPoint(MMsToCoord(1.6115), MMsToCoord(-1.6115));
        NewContour.AddPoint(MMsToCoord(0.2765), MMsToCoord(-1.6115));
        NewContour.AddPoint(MMsToCoord(0.2765), MMsToCoord(-0.2765));
        NewContour.AddPoint(MMsToCoord(1.6115), MMsToCoord(-0.2765));
        NewContour.AddPoint(MMsToCoord(1.6115), MMsToCoord(-1.6115));
        NewRegion.SetOutlineContour(NewContour);
        NewRegion.Layer := eTopPaste;
        NewPCBLibComp.AddPCBObject(NewRegion);

        NewRegion := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
        NewContour := PCBServer.PCBContourFactory;
        NewContour.AddPoint(MMsToCoord(1.6115), MMsToCoord(0.2765));
        NewContour.AddPoint(MMsToCoord(0.2765), MMsToCoord(0.2765));
        NewContour.AddPoint(MMsToCoord(0.2765), MMsToCoord(1.6115));
        NewContour.AddPoint(MMsToCoord(1.6115), MMsToCoord(1.6115));
        NewContour.AddPoint(MMsToCoord(1.6115), MMsToCoord(0.2765));
        NewRegion.SetOutlineContour(NewContour);
        NewRegion.Layer := eTopPaste;
        NewPCBLibComp.AddPCBObject(NewRegion);

        NewRegion := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
        NewContour := PCBServer.PCBContourFactory;
        NewContour.AddPoint(MMsToCoord(-0.2765), MMsToCoord(-1.6115));
        NewContour.AddPoint(MMsToCoord(-1.6115), MMsToCoord(-1.6115));
        NewContour.AddPoint(MMsToCoord(-1.6115), MMsToCoord(-0.2765));
        NewContour.AddPoint(MMsToCoord(-0.2765), MMsToCoord(-0.2765));
        NewContour.AddPoint(MMsToCoord(-0.2765), MMsToCoord(-1.6115));
        NewRegion.SetOutlineContour(NewContour);
        NewRegion.Layer := eTopPaste;
        NewPCBLibComp.AddPCBObject(NewRegion);

        NewRegion := PCBServer.PCBObjectFactory(eRegionObject, eNoDimension, eCreate_Default);
        NewContour := PCBServer.PCBContourFactory;
        NewContour.AddPoint(MMsToCoord(-0.2765), MMsToCoord(0.2765));
        NewContour.AddPoint(MMsToCoord(-1.6115), MMsToCoord(0.2765));
        NewContour.AddPoint(MMsToCoord(-1.6115), MMsToCoord(1.6115));
        NewContour.AddPoint(MMsToCoord(-0.2765), MMsToCoord(1.6115));
        NewContour.AddPoint(MMsToCoord(-0.2765), MMsToCoord(0.2765));
        NewRegion.SetOutlineContour(NewContour);
        NewRegion.Layer := eTopPaste;
        NewPCBLibComp.AddPCBObject(NewRegion);

        CreateComponentTrack(NewPCBLibComp, -2.38, -3.5, -2.38, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -2.5, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.62, -3.07, -2.62, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.62, -3.5, -2.38, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.88, -3.5, -1.88, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -2, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.12, -3.07, -2.12, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.12, -3.5, -1.88, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.38, -3.5, -1.38, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -1.5, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.62, -3.07, -1.62, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.62, -3.5, -1.38, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.88, -3.5, -0.88, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -1, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.12, -3.07, -1.12, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.12, -3.5, -0.88, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.38, -3.501, -0.38, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -0.5, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.62, -3.07, -0.62, -3.501, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.62, -3.501, -0.38, -3.501, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.12, -3.501, 0.12, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 0, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.12, -3.07, -0.12, -3.501, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.12, -3.501, 0.12, -3.501, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.62, -3.5, 0.62, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 0.5, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.38, -3.07, 0.38, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.38, -3.5, 0.62, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.12, -3.5, 1.12, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 1, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.88, -3.07, 0.88, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.88, -3.5, 1.12, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.62, -3.5, 1.62, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 1.5, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.38, -3.07, 1.38, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.38, -3.5, 1.62, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.12, -3.5, 2.12, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 2, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.88, -3.07, 1.88, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.88, -3.5, 2.12, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.62, -3.5, 2.62, -3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 2.5, -3.07, 0.12, 0, 180, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.38, -3.07, 2.38, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.38, -3.5, 2.62, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -2.38, 3.07, -2.38, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, -2.5, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, -2.62, 3.5, -2.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -2.62, 3.5, -2.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -1.88, 3.07, -1.88, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, -2, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, -2.12, 3.5, -2.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -2.12, 3.5, -1.88, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -1.38, 3.07, -1.38, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, -1.5, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, -1.62, 3.5, -1.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -1.62, 3.5, -1.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -0.88, 3.07, -0.88, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, -1, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, -1.12, 3.5, -1.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -1.12, 3.5, -0.88, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -0.38, 3.07, -0.38, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, -0.5, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, -0.62, 3.5, -0.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -0.62, 3.5, -0.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 0.12, 3.07, 0.12, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, 0, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, -0.12, 3.5, -0.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -0.12, 3.5, 0.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 0.62, 3.07, 0.62, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, 0.5, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, 0.38, 3.5, 0.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 0.38, 3.5, 0.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 1.12, 3.07, 1.12, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, 1, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, 0.88, 3.5, 0.88, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 0.88, 3.5, 1.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 1.62, 3.07, 1.62, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, 1.5, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, 1.38, 3.5, 1.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 1.38, 3.5, 1.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 2.12, 3.07, 2.12, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, 2, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, 1.88, 3.5, 1.88, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 1.88, 3.5, 2.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 2.62, 3.07, 2.62, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 3.07, 2.5, 0.12, 90, 270, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.07, 2.38, 3.5, 2.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 2.38, 3.5, 2.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.38, 3.5, 2.38, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 2.5, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.62, 3.07, 2.62, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.62, 3.5, 2.38, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.88, 3.5, 1.88, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 2, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.12, 3.07, 2.12, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.12, 3.5, 1.88, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.38, 3.5, 1.38, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 1.5, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.62, 3.07, 1.62, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.62, 3.5, 1.38, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.88, 3.5, 0.88, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 1, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.12, 3.07, 1.12, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.12, 3.5, 0.88, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.38, 3.5, 0.38, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 0.5, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.62, 3.07, 0.62, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.62, 3.5, 0.38, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.12, 3.501, -0.12, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, 0, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.12, 3.07, 0.12, 3.501, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.12, 3.501, -0.12, 3.501, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.62, 3.501, -0.62, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -0.5, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.38, 3.07, -0.38, 3.501, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.38, 3.501, -0.62, 3.501, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.12, 3.5, -1.12, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -1, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.88, 3.07, -0.88, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.88, 3.5, -1.12, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.62, 3.5, -1.62, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -1.5, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.38, 3.07, -1.38, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.38, 3.5, -1.62, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.12, 3.5, -2.12, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -2, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.88, 3.07, -1.88, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.88, 3.5, -2.12, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.62, 3.5, -2.62, 3.07, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -2.5, 3.07, 0.12, 180, 360, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.38, 3.07, -2.38, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.38, 3.5, -2.62, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 2.38, -3.071, 2.38, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, 2.5, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, 2.62, -3.501, 2.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 2.62, -3.501, 2.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 1.88, -3.071, 1.88, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, 2, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, 2.12, -3.501, 2.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 2.12, -3.501, 1.88, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 1.38, -3.071, 1.38, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, 1.5, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, 1.62, -3.501, 1.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 1.62, -3.501, 1.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 0.88, -3.071, 0.88, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, 1, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, 1.12, -3.501, 1.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 1.12, -3.501, 0.88, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 0.38, -3.071, 0.38, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, 0.5, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, 0.62, -3.501, 0.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 0.62, -3.501, 0.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -0.12, -3.071, -0.12, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, 0, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, 0.12, -3.501, 0.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, 0.12, -3.501, -0.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -0.62, -3.071, -0.62, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, -0.5, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, -0.38, -3.501, -0.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -0.38, -3.501, -0.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -1.12, -3.071, -1.12, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, -1, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, -0.88, -3.501, -0.88, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -0.88, -3.501, -1.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -1.62, -3.071, -1.62, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, -1.5, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, -1.38, -3.501, -1.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -1.38, -3.501, -1.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -2.12, -3.071, -2.12, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, -2, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, -1.88, -3.501, -1.88, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -1.88, -3.501, -2.12, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -2.62, -3.071, -2.62, eMechanical5, 0.025, False);
        CreateComponentArc(NewPCBLibComp, -3.071, -2.5, 0.12, 270, 450, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.071, -2.38, -3.501, -2.38, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.501, -2.38, -3.501, -2.62, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.888, -1.638, -1.888, 1.888, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.888, 1.888, 1.888, 1.888, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.888, 1.888, 1.888, -1.888, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.888, -1.888, -1.638, -1.888, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.638, -1.888, -1.888, -1.638, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.5, -3.5, -3.5, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.5, 3.5, 3.5, 3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 3.5, 3.5, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -3.5, -3.5, -3.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.5, -3.5, -3.5, 3.5, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -3.5, 3.5, 3.5, 3.5, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 3.5, 3.5, -3.5, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -3.5, -3.5, -3.5, eMechanical3, 0.12, False);
        CreateComponentArc(NewPCBLibComp, 0, 0, 0.25, 0, 360, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0.35, 0, -0.35, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -0.35, 0, 0.35, 0, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.812, -3.5, -3.5, -3.5, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -3.5, -3.5, -3.5, -2.812, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 2.812, -3.5, 3.5, -3.5, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, -3.5, 3.5, -2.812, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 2.812, 3.5, 3.5, 3.5, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 3.5, 3.5, 3.5, 2.812, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -2.812, 3.5, -3.5, 3.5, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -3.5, 3.5, -3.5, 2.812, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 3.7, -3.7, 3.7, -2.832, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 3.7, -2.832, 3.956, -2.832, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 3.956, -2.832, 3.956, 2.832, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 3.956, 2.832, 3.7, 2.832, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 3.7, 2.832, 3.7, 3.7, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 3.7, 3.7, 2.832, 3.7, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.832, 3.7, 2.832, 3.956, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.832, 3.956, -2.832, 3.956, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.832, 3.956, -2.832, 3.7, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.832, 3.7, -3.7, 3.7, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -3.7, 3.7, -3.7, 2.832, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -3.7, 2.832, -3.956, 2.832, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -3.956, 2.832, -3.956, -2.832, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -3.956, -2.832, -3.7, -2.832, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -3.7, -2.832, -3.7, -3.7, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -3.7, -3.7, -2.832, -3.7, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.832, -3.7, -2.832, -3.956, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.832, -3.956, 2.832, -3.956, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.832, -3.956, 2.832, -3.7, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.832, -3.7, 3.7, -3.7, eMechanical7, 0.05, False);

        STEPmodel := PcbServer.PCBObjectFactory(eComponentBodyObject, eNoDimension, eCreate_Default);
        Model := STEPmodel.ModelFactory_FromFilename('C:\Users\ivans\Desktop\FESB Racing\Altium GIT\Components\Script\QFN45P50_700X700X100L55X24T377.STEP', false);
        STEPModel.Layer := eMechanical1;
        STEPmodel.Model := Model;
        STEPmodel.SetState_Identifier(NewPcbLibComp.Name);
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
    Document : IServerDocument;
    TempPCBLibComp : IPCB_LibComponent;

Begin
    Document := CreateNewDocumentFromDocumentKind('PCBLib');

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

    Document.Modified := True;

    // Create And focus a temporary component While we delete items (BugCrunch #10165)
    TempPCBLibComp := PCBServer.CreatePCBLibComp;
    TempPcbLibComp.Name := '___TemporaryComponent___';
    CurrentLib.RegisterComponent(TempPCBLibComp);
    CurrentLib.CurrentComponent := TempPcbLibComp;
    CurrentLib.Board.ViewManager_FullUpdate;

    CreateComponentQFN45P50_700X700X100L55X24T377N(0);

    // Delete Temporary Footprint And re-focus
    CurrentLib.RemoveComponent(TempPCBLibComp);
    CurrentLib.Board.ViewManager_UpdateLayerTabs;
    CurrentLib.Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=All', 255, Client.CurrentView)
End;

Procedure CreateALibrary;
Begin
    Screen.Cursor := crHourGlass;

    CreateAPCBLibrary(0);

    Screen.Cursor := crArrow;
End;

End.
