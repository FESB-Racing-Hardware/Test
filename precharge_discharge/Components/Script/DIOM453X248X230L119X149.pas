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

Procedure CreateComponentDIOM453X248X230L119X149(Zero : integer);
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

        NewPcbLibComp := CreateAComponent('DIOM453X248X230L119X149');
        NewPcbLibComp.Name := 'DIOM453X248X230L119X149';
        NewPCBLibComp.Description := 'Diode, Molded Body; 4.315 mm L X 2.485 mm W X 2.30 mm H body';
        NewPCBLibComp.Height := MMsToCoord(2.3);

        CreateSMDComponentPad(NewPCBLibComp, 'C', eTopLayer, -1.7, 0, 0, 0, eRoundedRectangular, 1.52, 1.68, 180, 26.32, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, 'A', eTopLayer, 1.7, 0, 0, 0, eRoundedRectangular, 1.52, 1.68, 0, 26.32, 0, 0, True, True);

        CreateComponentTrack(NewPCBLibComp, -1.0705, 0.7475, -1.0705, -0.7475, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.0705, -0.7475, -2.2655, -0.7475, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.2655, -0.7475, -2.2655, 0.7475, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.2655, 0.7475, -1.0705, 0.7475, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.0705, -0.7475, 1.0705, 0.7475, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.0705, 0.7475, 2.2655, 0.7475, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.2655, 0.7475, 2.2655, -0.7475, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.2655, -0.7475, 1.0705, -0.7475, eMechanical5, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.1575, -1.2425, -2.1575, 1.2425, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.1575, 1.2425, 2.1575, 1.2425, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.1575, 1.2425, 2.1575, -1.2425, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.1575, -1.2425, -2.1575, -1.2425, eMechanical7, 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.285, -1.395, -2.285, 1.395, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -2.285, 1.395, 2.285, 1.395, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 2.285, 1.395, 2.285, -1.395, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 2.285, -1.395, -2.285, -1.395, eMechanical3, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -2.285, 1.395, 2.285, 1.395, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -2.285, -1.395, 2.285, -1.395, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -2.285, -1.395, -2.285, -1.02, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -2.285, 1.02, -2.285, 1.395, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 2.285, -1.395, 2.285, -1.02, eTopOverlay, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 2.285, 1.02, 2.285, 1.395, eTopOverlay, 0.12, False);
        CreateComponentArc(NewPCBLibComp, 0, 0, 0.25, 0, 360, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0.35, 0, -0.35, 0, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0.35, 0, -0.35, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.485, -1.595, 2.485, -1.595, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.485, -1.595, 2.485, -1.04, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.485, -1.04, 2.66, -1.04, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.66, -1.04, 2.66, 1.04, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.66, 1.04, 2.485, 1.04, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.485, 1.04, 2.485, 1.595, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 2.485, 1.595, -2.485, 1.595, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.485, 1.595, -2.485, 1.04, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.485, 1.04, -2.66, 1.04, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.66, 1.04, -2.66, -1.04, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.66, -1.04, -2.485, -1.04, eMechanical7, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -2.485, -1.04, -2.485, -1.595, eMechanical7, 0.05, False);

        STEPmodel := PcbServer.PCBObjectFactory(eComponentBodyObject, eNoDimension, eCreate_Default);
        Model := STEPmodel.ModelFactory_FromFilename('C:\Users\Korisnik\Desktop\FESB Racing\Components\Script\DIOM453X248X230L119X149.STEP', false);
        STEPModel.Layer := eMechanical1;
        STEPmodel.Model := Model;
        STEPmodel.SetState_Identifier('DIOM453X248X230L119X149');
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

    CreateComponentDIOM453X248X230L119X149(0);

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
