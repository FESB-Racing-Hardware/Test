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

Procedure CreateComponentSIP900W100P500L3000H1250Q6(Zero : integer);
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

        NewPcbLibComp := CreateAComponent('SIP900W100P500L3000H1250Q6');
        NewPcbLibComp.Name := 'SIP900W100P500L3000H1250Q6';
        NewPCBLibComp.Description := 'SIP, 5.00 mm pitch; 6 pin, 30.00 mm L X 9.00 mm W X 12.50 mm H body';
        NewPCBLibComp.Height := MMsToCoord(12.5);

        CreateTHComponentPad(NewPCBLibComp, '1', eRoundHole, 1.55, 0, eBottomLayer, -12.5, 0, 0, 0, eRectangular, 2.33, 2.33, eRounded, 2.33, 2.33, eRectangular, 2.33, 2.33, 270, 0, -2.33, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '2', eRoundHole, 1.55, 0, eBottomLayer, -7.5, 0, 0, 0, eRounded, 2.33, 2.33, eRounded, 2.33, 2.33, eRounded, 2.33, 2.33, 0, 0, -2.33, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '3', eRoundHole, 1.55, 0, eBottomLayer, -2.5, 0, 0, 0, eRounded, 2.33, 2.33, eRounded, 2.33, 2.33, eRounded, 2.33, 2.33, 0, 0, -2.33, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '4', eRoundHole, 1.55, 0, eBottomLayer, 2.5, 0, 0, 0, eRounded, 2.33, 2.33, eRounded, 2.33, 2.33, eRounded, 2.33, 2.33, 0, 0, -2.33, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '5', eRoundHole, 1.55, 0, eBottomLayer, 7.5, 0, 0, 0, eRounded, 2.33, 2.33, eRounded, 2.33, 2.33, eRounded, 2.33, 2.33, 0, 0, -2.33, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '6', eRoundHole, 1.55, 0, eBottomLayer, 12.5, 0, 0, 0, eRounded, 2.33, 2.33, eRounded, 2.33, 2.33, eRounded, 2.33, 2.33, 0, 0, -2.33, 0, True);

        CreateComponentTrack(NewPCBLibComp, -13, 0.5, -12, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -12, 0.5, -12, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -12, -0.5, -13, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -13, -0.5, -13, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, 0.5, -7, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7, 0.5, -7, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -7, -0.5, -8, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -8, -0.5, -8, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3, 0.5, -2, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2, 0.5, -2, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2, -0.5, -3, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3, -0.5, -3, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2, 0.5, 3, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3, 0.5, 3, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3, -0.5, 2, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2, -0.5, 2, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7, 0.5, 8, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, 0.5, 8, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 8, -0.5, 7, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 7, -0.5, 7, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 12, 0.5, 13, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 13, 0.5, 13, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 13, -0.5, 12, -0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 12, -0.5, 12, 0.5, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -15, -4.5, -15, 4.5, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -15, 4.5, 15, 4.5, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 15, 4.5, 15, -4.5, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 15, -4.5, -15, -4.5, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -15, -4.5, -15, 4.5, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -15, 4.5, 15, 4.5, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 15, 4.5, 15, -4.5, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 15, -4.5, -15, -4.5, eMechanical3, 0.12, False);
        CreateComponentArc(NewPCBLibComp, 0, 0, 0.25, 0, 360, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0.35, 0, -0.35, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -0.35, 0, 0.35, 0, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 13.89, -4.5, 15, -4.5, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, 15, -4.5, 15, 4.5, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, 15, 4.5, 13.89, 4.5, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, -13.89, -4.5, -15, -4.5, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, -15, -4.5, -15, 4.5, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, -15, 4.5, -13.89, 4.5, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, 15.25, -4.75, 15.25, 4.75, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 15.25, 4.75, -15.25, 4.75, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -15.25, 4.75, -15.25, -4.75, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -15.25, -4.75, 15.25, -4.75, eMechanical7, 0.05, False);

        STEPmodel := PcbServer.PCBObjectFactory(eComponentBodyObject, eNoDimension, eCreate_Default);
        Model := STEPmodel.ModelFactory_FromFilename('C:\Users\Korisnik\Desktop\FESB Racing\Components\Script\SIP900W100P500L3000H1250Q6.STEP', false);
        STEPModel.Layer := eMechanical1;
        STEPmodel.Model := Model;
        STEPmodel.SetState_Identifier('SIP900W100P500L3000H1250Q6');
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

    CreateComponentSIP900W100P500L3000H1250Q6(0);

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
