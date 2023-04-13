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

Procedure CreateTHComponentPad(NewPCBLibComp : IPCB_LibComponent, Name : String, HoleType : TExtendedHoleType,
                               HoleSize : Real, HoleLength : Real, Layer : TLayer, X : Real, Y : Real,
                               OffsetX : Real, OffsetY : Real, TopShape : TShape, TopXSize : Real, TopYSize : Real,
                               InnerShape : TShape, InnerXSize : Real, InnerYSize : Real,
                               BottomShape : TShape, BottomXSize : Real, BottomYSize : Real,
                               Rotation: Real, CRRatio : Real, PMExpansion : Real, SMExpansion: Real, Plated : Boolean);
Var
    NewPad                      : IPCB_Pad2;
    PadCache                    : TPadCache;

Begin
    NewPad := PcbServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    NewPad.Mode := ePadMode_LocalStack;
    NewPad.HoleType := HoleType;
    NewPad.HoleSize := MMsToCoord(HoleSize);
    if HoleLength <> 0 then
        NewPad.HoleWidth := MMsToCoord(HoleLength);
    NewPad.TopShape := TopShape;
    if TopShape = eRoundedRectangular then
        NewPad.SetState_StackCRPctOnLayer(eTopLayer, CRRatio);
    if BottomShape = eRoundedRectangular then
        NewPad.SetState_StackCRPctOnLayer(eBottomLayer, CRRatio);
    NewPad.TopXSize := MMsToCoord(TopXSize);
    NewPad.TopYSize := MMsToCoord(TopYSize);
    NewPad.MidShape := InnerShape;
    NewPad.MidXSize := MMsToCoord(InnerXSize);
    NewPad.MidYSize := MMsToCoord(InnerYSize);
    NewPad.BotShape := BottomShape;
    NewPad.BotXSize := MMsToCoord(BottomXSize);
    NewPad.BotYSize := MMsToCoord(BottomYSize);
    NewPad.SetState_XPadOffsetOnLayer(Layer, MMsToCoord(OffsetX));
    NewPad.SetState_YPadOffsetOnLayer(Layer, MMsToCoord(OffsetY));
    NewPad.RotateBy(Rotation);
    NewPad.MoveToXY(MMsToCoord(X), MMsToCoord(Y));
    NewPad.Plated   := Plated;
    NewPad.Name := Name;

    Padcache := NewPad.GetState_Cache;
    if PMExpansion <> 0 then
    Begin
        Padcache.PasteMaskExpansionValid   := eCacheManual;
        Padcache.PasteMaskExpansion        := MMsToCoord(PMExpansion);
    End;
    if SMExpansion <> 0 then
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

Procedure CreateComponentSHDRRA2W50P350_2X1_800X1340H896N(Zero : integer);
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

        NewPcbLibComp := CreateAComponent('SHDRRA2W50P350_2X1_800X1340H896N');
        NewPcbLibComp.Name := 'SHDRRA2W50P350_2X1_800X1340H896N';
        NewPCBLibComp.Description := 'Header, Right Angle Shrouded, 3.50 mm pitch; 0.50 mm lead width, 2 pins, 1 row, 2 pins per row, 8.00 mm L X 13.40 mm W X 8.96 mm H Body';
        NewPCBLibComp.Height := MMsToCoord(8.96);

        CreateTHComponentPad(NewPCBLibComp, '1', eRoundHole, 0.857, 0, eBottomLayer, 0, 0, 0, 0, eRectangular, 1.286, 1.286, eRounded, 1.286, 1.286, eRectangular, 1.286, 1.286, 0, 0, -1.286, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '2', eRoundHole, 0.857, 0, eBottomLayer, 3.5, 0, 0, 0, eRounded, 1.286, 1.286, eRounded, 1.286, 1.286, eRounded, 1.286, 1.286, 0, 0, -1.286, 0, True);

        CreateComponentTrack(NewPCBLibComp, -0.25, -0.25, -0.25, 0.25, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.25, 0.25, 0.25, 0.25, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.25, 0.25, 0.25, -0.25, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.25, -0.25, -0.25, -0.25, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.25, -0.25, 3.25, 0.25, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.25, 0.25, 3.75, 0.25, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.75, 0.25, 3.75, -0.25, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.75, -0.25, 3.25, -0.25, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.25, -11.2, -2.25, 2.2, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.25, 2.2, 5.75, 2.2, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.75, 2.2, 5.75, -11.2, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.75, -11.2, -2.25, -11.2, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.25, -11.2, -2.25, 2.2, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -2.25, 2.2, 5.75, 2.2, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 5.75, 2.2, 5.75, -11.2, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 5.75, -11.2, -2.25, -11.2, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -2.5, -11.45, -2.5, 2.45, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.5, 2.45, 6, 2.45, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 6, 2.45, 6, -11.45, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 6, -11.45, -2.5, -11.45, eMechanical7, 0.05, False);
        CreateComponentArc(NewPCBLibComp, 0, 0, 0.25, 0, 360, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0.35, 0, -0.35, 0, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0.35, 0, -0.35, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.25, -0.643, -2.25, -11.2, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -2.25, -11.2, 5.75, -11.2, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 5.75, -11.2, 5.75, -0.643, eTopOverlay, 0.12, False);

        STEPmodel := PcbServer.PCBObjectFactory(eComponentBodyObject, eNoDimension, eCreate_Default);
        Model := STEPmodel.ModelFactory_FromFilename('C:\Users\ivans\Desktop\FESB Racing\Altium\Hardware\Components\Script\SHDRRA2W50P350_2X1_800X1340H896.STEP', false);
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

    CreateComponentSHDRRA2W50P350_2X1_800X1340H896N(0);

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
