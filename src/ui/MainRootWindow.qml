/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Controls 2.4
import QtQuick.Dialogs  1.3
import QtQuick.Layouts  1.11
import QtQuick.Window   2.11

import QGroundControl               1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.FlightDisplay 1.0
import QGroundControl.FlightMap     1.0

//test OfflineMap

import QtLocation 5.6
import QtPositioning 5.6




/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:             mainWindow
    minimumWidth:   ScreenTools.isMobile ? Screen.width  : Math.min(ScreenTools.defaultFontPixelWidth * 100, Screen.width)
    minimumHeight:  ScreenTools.isMobile ? Screen.height : Math.min(ScreenTools.defaultFontPixelWidth * 50, Screen.height)
    visible:        true
    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle //RYY


    Component.onCompleted: {
        //-- Full screen on mobile or tiny screens
        if (ScreenTools.isMobile || Screen.height / ScreenTools.realPixelDensity < 120) {
            mainWindow.showFullScreen()
        } else {
            width   = ScreenTools.isMobile ? Screen.width  : Math.min(250 * Screen.pixelDensity, Screen.width)
            height  = ScreenTools.isMobile ? Screen.height : Math.min(150 * Screen.pixelDensity, Screen.height)
        }

        // Start the sequence of first run prompt(s)
        firstRunPromptManager.nextPrompt()
    }

    QtObject {
        id: firstRunPromptManager

        property var currentDialog:     null
        property var rgPromptIds:       QGroundControl.corePlugin.firstRunPromptsToShow()
        property int nextPromptIdIndex: 0

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt)
            }
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(rgPromptIds[nextPromptIdIndex]));
                currentDialog = component.createObject(mainWindow)
                currentDialog.closed.connect(nextPrompt)
                currentDialog.open()
                nextPromptIdIndex++
            } else {
                currentDialog = null
                showPreFlightChecklistIfNeeded()
            }
        }
    }

    property var                _rgPreventViewSwitch:       [ false ]

    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var       activeVehicle:                  QGroundControl.multiVehicleManager.activeVehicle
        readonly property real      defaultTextHeight:              ScreenTools.defaultFontPixelHeight
        readonly property real      defaultTextWidth:               ScreenTools.defaultFontPixelWidth
        readonly property var       planMasterControllerFlyView:    flightView.planController
        readonly property var       guidedControllerFlyView:        flightView.guidedController

        property var                planMasterControllerPlanView:   null
        property var                currentPlanMissionItem:         planMasterControllerPlanView ? planMasterControllerPlanView.missionController.currentPlanViewItem : null

        // Property to manage RemoteID quick acces to settings page
        property bool               commingFromRIDIndicator:        false
    }

    /// Default color palette used throughout the UI
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal forceArmVehicleRequest
    signal disarmVehicleRequest
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest
    signal showPreFlightChecklistIfNeeded

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    /// Prevent view switching
    function pushPreventViewSwitch() {
        _rgPreventViewSwitch.push(true)
    }

    /// Allow view switching
    function popPreventViewSwitch() {
        if (_rgPreventViewSwitch.length == 1) {
            console.warn("mainWindow.popPreventViewSwitch called when nothing pushed")
            return
        }
        _rgPreventViewSwitch.pop()
    }

    /// @return true: View switches are not currently allowed
    function preventViewSwitch() {
        return _rgPreventViewSwitch[_rgPreventViewSwitch.length - 1]
    }

    function viewSwitch(currentToolbar) {
        toolDrawer.visible      = false
        toolDrawer.toolSource   = ""
        flightView.visible      = false
        planView.visible        = false
        toolbar.currentToolbar  = currentToolbar
    }

    function showFlyView() {
        if (!flightView.visible) {
            mainWindow.showPreFlightChecklistIfNeeded()
        }
        viewSwitch(toolbar.flyViewToolbar)
        flightView.visible = true
    }

    function showPlanView() {
        viewSwitch(toolbar.planViewToolbar)
        planView.visible = true
    }

    function showTool(toolTitle, toolSource, toolIcon) {
        toolDrawer.backIcon     = flightView.visible ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Plan.svg"
        toolDrawer.toolTitle    = toolTitle
        toolDrawer.toolSource   = toolSource
        toolDrawer.toolIcon     = toolIcon
        toolDrawer.visible      = true
    }

    function showAnalyzeTool() {
        showTool(qsTr("Analyze Tools"), "AnalyzeView.qml", "/qmlimages/Analyze.svg")
    }

    function showSetupTool() {
        showTool(qsTr("Vehicle Setup"), "SetupView.qml", "/qmlimages/Gears.svg")
    }

    function showSettingsTool() {
        showTool(qsTr("Application Settings"), "AppSettings.qml", "/res/rovostechlogo") //RYY
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function showMessageDialog(dialogTitle, dialogText, buttons = StandardButton.Ok, acceptFunction = null) {
        simpleMessageDialogComponent.createObject(mainWindow, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction }).open()
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        showMessageDialog(dialogTitle, dialogText)
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    /// Saves main window position and size
    MainWindowSavedState {
        window: mainWindow
    }

    property bool _forceClose: false

    function finishCloseProcess() {
        _forceClose = true
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        firstRunPromptManager.clearNextPromptSignal()
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // On attempting an application close we check for:
    //  Unsaved missions - then
    //  Pending parameter writes - then
    //  Active connections

    property string closeDialogTitle: qsTr("Close Rovotun").arg(QGroundControl.appName)

    function checkForUnsavedMission() {
        if (globals.planMasterControllerPlanView && globals.planMasterControllerPlanView.dirty) {
            showMessageDialog(closeDialogTitle,
                              qsTr("You have a mission edit in progress which has not been saved/sent. If you close you will lose changes. Are you sure you want to close?"),
                              StandardButton.Yes | StandardButton.No,
                              function() { checkForPendingParameterWrites() })
        } else {
            checkForPendingParameterWrites()
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                mainWindow.showMessageDialog(closeDialogTitle,
                    qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
                    StandardButton.Yes | StandardButton.No,
                    function() { checkForActiveConnections() })
                return
            }
        }
        checkForActiveConnections()
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            mainWindow.showMessageDialog(closeDialogTitle,
                qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
                StandardButton.Yes | StandardButton.No,
                function() { finishCloseProcess() })
        } else {
            finishCloseProcess()
        }
    }

    onClosing: {
        if (!_forceClose) {
            close.accepted = false
            checkForUnsavedMission()
        }
    }

    //-------------------------------------------------------------------------
    /// Main, full window background (Fly View)
    background: Item {
        id:             rootBackground
        anchors.fill:   parent
    }
    // compas and INS

    //-------------------------------------------------------------------------
    /// Toolbar
    header: MainToolBar {
        id:         toolbar
        height:     ScreenTools.toolbarHeight
        visible:    !(QGroundControl.videoManager.fullScreen && flightView.visible)
    }

    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    function showToolSelectDialog() {
        if (!mainWindow.preventViewSwitch()) {
            toolSelectDialogComponent.createObject(mainWindow).open()
        }
    }

    Component {
        id: toolSelectDialogComponent

        QGCPopupDialog {
            id:         toolSelectDialog
            title:      qsTr("Select Tool")
            buttons:    StandardButton.Close

            property real _toolButtonHeight:    ScreenTools.defaultFontPixelHeight * 3
            property real _margins:             ScreenTools.defaultFontPixelWidth

            ColumnLayout {
                width:  innerLayout.width + (toolSelectDialog._margins * 2)
                height: innerLayout.height + (toolSelectDialog._margins * 2)

                ColumnLayout {
                    id:             innerLayout
                    Layout.margins: toolSelectDialog._margins
                    spacing:        ScreenTools.defaultFontPixelWidth

                    SubMenuButton {
                        id:                 setupButton
                        height:             toolSelectDialog._toolButtonHeight
                        Layout.fillWidth:   true
                        text:               qsTr("Vehicle Setup")
                        imageColor:         qgcPal.text
                        imageResource:      "/qmlimages/Gears.svg"
                        onClicked: {
                            if (!mainWindow.preventViewSwitch()) {
                                toolSelectDialog.close()
                                mainWindow.showSetupTool()
                            }
                        }
                    }

                    SubMenuButton {
                        id:                 analyzeButton
                        height:             toolSelectDialog._toolButtonHeight
                        Layout.fillWidth:   true
                        text:               qsTr("Analyze Tools")
                        imageResource:      "/qmlimages/Analyze.svg"
                        imageColor:         qgcPal.text
                        visible:            QGroundControl.corePlugin.showAdvancedUI
                        onClicked: {
                            if (!mainWindow.preventViewSwitch()) {
                                toolSelectDialog.close()
                                mainWindow.showAnalyzeTool()
                            }
                        }
                    }

                    SubMenuButton {
                        id:                 settingsButton
                        height:             toolSelectDialog._toolButtonHeight
                        Layout.fillWidth:   true
                        text:               qsTr("Application Settings")
                        imageResource:      "/res/rovostechlogo" //RYY
                        imageColor:         "transparent"
                        visible:            !QGroundControl.corePlugin.options.combineSettingsAndSetup
                        onClicked: {
                            if (!mainWindow.preventViewSwitch()) {
                                toolSelectDialog.close()
                                mainWindow.showSettingsTool()
                            }
                        }
                    }

                    ColumnLayout {
                        width:                  innerLayout.width
                        spacing:                0
                        Layout.alignment:       Qt.AlignHCenter

                        QGCLabel {
                            id:                     versionLabel
                            text:                   qsTr("ROVOTUN").arg(QGroundControl.appName)
                            font.pointSize:         ScreenTools.smallFontPointSize
                            wrapMode:               QGCLabel.WordWrap
                            Layout.maximumWidth:    parent.width
                            Layout.alignment:       Qt.AlignHCenter
                        }

                        QGCLabel {
                            text:                   qsTr("V1")
                            font.pointSize:         ScreenTools.smallFontPointSize
                            wrapMode:               QGCLabel.WrapAnywhere
                            Layout.maximumWidth:    parent.width
                            Layout.alignment:       Qt.AlignHCenter

                            QGCMouseArea {
                                id:                 easterEggMouseArea
                                anchors.topMargin:  -versionLabel.height
                                anchors.fill:       parent

                                onClicked: {
                                    if (mouse.modifiers & Qt.ControlModifier) {
                                        QGroundControl.corePlugin.showTouchAreas = !QGroundControl.corePlugin.showTouchAreas
                                    } else if (mouse.modifiers & Qt.ShiftModifier) {
                                        if(!QGroundControl.corePlugin.showAdvancedUI) {
                                            advancedModeConfirmation.open()
                                        } else {
                                            QGroundControl.corePlugin.showAdvancedUI = false
                                        }
                                    }
                                }

                                MessageDialog {
                                    id:                 advancedModeConfirmation
                                    title:              qsTr("Advanced Mode")
                                    text:               QGroundControl.corePlugin.showAdvancedUIMessage
                                    standardButtons:    StandardButton.Yes | StandardButton.No
                                    onYes: {
                                        QGroundControl.corePlugin.showAdvancedUI = true
                                        advancedModeConfirmation.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    FlyView {
        id:             flightView
        anchors.fill:   parent
    }

    PlanView {
        id:             planView
        anchors.fill:   parent
        visible:        false
    }

    Drawer {
        id:             toolDrawer
        width:          mainWindow.width
        height:         mainWindow.height
        edge:           Qt.LeftEdge
        dragMargin:     0
        closePolicy:    Drawer.NoAutoClose
        interactive:    false
        visible:        false

        property alias backIcon:    backIcon.source
        property alias toolTitle:   toolbarDrawerText.text
        property alias toolSource:  toolDrawerLoader.source
        property alias toolIcon:    toolIcon.source

        Rectangle {
            id:             toolDrawerToolbar
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            height:         ScreenTools.toolbarHeight
            color:          qgcPal.toolbarBackground

            RowLayout {
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.left:       parent.left
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                spacing:            ScreenTools.defaultFontPixelWidth

                QGCColoredImage {
                    id:                     backIcon
                    width:                  ScreenTools.defaultFontPixelHeight * 2
                    height:                 ScreenTools.defaultFontPixelHeight * 2
                    fillMode:               Image.PreserveAspectFit
                    mipmap:                 true
                    color:                  qgcPal.text
                }

                QGCLabel {
                    id:     backTextLabel
                    text:   qsTr("Back")
                }

                QGCLabel {
                    font.pointSize: ScreenTools.largeFontPointSize
                    text:           "<"
                }

                QGCColoredImage {
                    id:                     toolIcon
                    width:                  ScreenTools.defaultFontPixelHeight * 2
                    height:                 ScreenTools.defaultFontPixelHeight * 2
                    fillMode:               Image.PreserveAspectFit
                    mipmap:                 true
                    color:                  qgcPal.text
                }

                QGCLabel {
                    id:             toolbarDrawerText
                    font.pointSize: ScreenTools.largeFontPointSize
                }
            }

            QGCMouseArea {
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                x:                  parent.mapFromItem(backIcon, backIcon.x, backIcon.y).x
                width:              (backTextLabel.x + backTextLabel.width) - backIcon.x
                onClicked: {
                    toolDrawer.visible      = false
                    toolDrawer.toolSource   = ""
                }
            }
        }

        Loader {
            id:             toolDrawerLoader
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    toolDrawerToolbar.bottom
            anchors.bottom: parent.bottom

            Connections {
                target:                 toolDrawerLoader.item
                ignoreUnknownSignals:   true
                onPopout:               toolDrawer.visible = false
            }
        }
    }



    // RYY ///////////////////////////////////////////////////////////////////////////
    property bool bIsFoldSet: false;
    function onFoldSet() {
            if (bIsFoldSet) {
                bIsFoldSet = false;
            }
            else {
                bIsFoldSet = true;
            }
            r1.visible = bIsFoldSet;
        }





    Rectangle {
        id : folding
        width: 100
        height: 30
        radius: 5

        color : "#66060602"
        border.width: 1
        border.color: "#80ffffff"

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 0

        objectName: "item"

        QGCButton{
            id: buttonfold
            x: 0
            y: 0
            width: 100
            height: 30
            text: qsTr("Rovotun Utility")
            anchors.verticalCenterOffset: 0
            anchors.horizontalCenterOffset: 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                            anchors.fill: parent
                            onClicked:  {
                                onFoldSet();
                            }
                        }

        }
    }



    Rectangle {
        id : r1
        width: 391
        height: 150
        radius: 5
        visible: false

        color : "#66060602"
        border.width: 1
        border.color: "#80ffffff"

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 50

        objectName: "item"


        Rectangle {
            id:                 visualInstrument
            height:             100 * 2
            Layout.fillWidth:   true
            radius:             100
            color:              qgcPal.window

            QGCLabel {
                id: exsINS
                x: 25
                y: 150
                width: 82
                height: 12
                text: qsTr("External INS")
                anchors.verticalCenterOffset: -100
                anchors.horizontalCenterOffset: 550
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 13
            }



            QGCAttitudeWidgetRovotun {
                id:                     attitude
                anchors.leftMargin:     400
                anchors.left:           parent.left
                size:                   65 * 2
                vehicle:                globals.activeVehicle
                anchors.verticalCenter: parent.verticalCenter

            }

            QGCCompassWidgetRovotun {
                id:                     compass
                anchors.leftMargin:     10
                anchors.left:           attitude.right
                size:                   65 * 2
                vehicle:                globals.activeVehicle
                anchors.verticalCenter: parent.verticalCenter

            }
        }

        QGCLabel {
            id: kalmantitle
            x: 25
            y: 150
            width: 82
            height: 30
            text: qsTr("Centering Kalman Filter Algorithm")
            anchors.verticalCenterOffset: -50
            anchors.horizontalCenterOffset: -50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
        }

        QGCLabel {
            id: element
            x: 25
            y: 150
            width: 82
            height: 12
            text: qsTr("Kalman Gain")
            anchors.verticalCenterOffset: -26
            anchors.horizontalCenterOffset: -147
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
        }






        QGCTextField {
            id: kalmangainvalue
            x: 257
            y: 150
            width: 30
            height: 22

            text: qsTr("250")

            visible: true
            anchors.verticalCenterOffset: -26
            anchors.horizontalCenterOffset: -90
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            selectByMouse: true
            font.pixelSize: 12

            inputMethodHints: Qt.ImhDigitsOnly // Ensures only digits are accepted RYY
                    validator: IntValidator  { // Restricts input
                        bottom: 0
                        top: 999 // Adjust upper limit as needed

                    }
            onTextChanged: {
                    if (_activeVehicle && kalmangainvalue.text !== "") {
                                _activeVehicle.setKalmangval(parseFloat(kalmangainvalue.text))
                            }
                    }
        }

        QGCLabel {
            id: noisecov
            x: 25
            y: 150
            width: 82
            height: 12
            text: qsTr("Sensor Noise")
            anchors.verticalCenterOffset: -26
            anchors.horizontalCenterOffset: -30
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
        }

        QGCTextField {
            id: noisecovm
            x: 257
            y: 150
            width: 30
            height: 22

            text: qsTr("0.5") // RYY

            visible: true
            anchors.verticalCenterOffset: -26
            anchors.horizontalCenterOffset: 30
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            selectByMouse: true
            font.pixelSize: 12
            inputMethodHints: Qt.ImhDigitsOnly // Ensures only digits are accepted RYY
                    validator: DoubleValidator  { // Restricts input
                        bottom: 0
                        top: 2 // Adjust upper limit as needed
                        decimals: 2 // Set to the number of decimal places you want to allow
                    }
            onTextChanged: {
                    if (_activeVehicle && noisecovm.text !== "") {
                                _activeVehicle.setnoiseval(parseFloat(noisecovm.text))
                            }
                    }

            QGCButton{
                id: increasenoise
                x: 0
                y: 0
                width: 15
                height: 15
                text: qsTr("+")
                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: 30
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                        var currentValue = parseFloat(noisecovm.text);
                        var newValue = currentValue + 0.1;
                        if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                            newValue = 2;
                        }
                        noisecovm.text = newValue.toFixed(1);
                    }



            }

            QGCButton{
                id: decreasenoise
                x: 0
                y: 0
                width: 15
                height: 15
                text: qsTr("-")
                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: 50
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                        var currentValue = parseFloat(noisecovm.text);
                        var newValue = currentValue - 0.1;
                        if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                            newValue = 2;
                        }
                        noisecovm.text = newValue.toFixed(1);
                    }



            }
        }


        QGCButton{
            id: connectudp
            x: 0
            y: 0
            visible: true
            width: 70
            height: 15
            text: qsTr("Connect")
            anchors.verticalCenterOffset: -26
            anchors.horizontalCenterOffset: 150
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter


            onClicked: {
                    if (_activeVehicle) {
                        _activeVehicle.connectionudp(50005);
                        _activeVehicle.connectionudp(50006);
                        _activeVehicle.connectionudp(50011);
                        _activeVehicle.connectionudp(50012);
                        _activeVehicle.connectionudp(50013);
                        _activeVehicle.connectionudp(50014);
                        visible = false; // Make the button disappear
                    }
                }


        }



        /*
        QGCLabel {
            id: safetydist
            x: 25
            y: 150
            width: 82
            height: 12
            text: qsTr("Safety Dist(m)")
            anchors.verticalCenterOffset: -26
            anchors.horizontalCenterOffset: 100
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
        }

        QGCTextField {
            id: safetydistm
            x: 257
            y: 150
            width: 30
            height: 22

            text: qsTr("0.5") // RYY

            visible: true
            anchors.verticalCenterOffset: -26
            anchors.horizontalCenterOffset: 160
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            selectByMouse: true
            font.pixelSize: 12

            inputMethodHints: Qt.ImhDigitsOnly // Ensures only digits are accepted RYY
                    validator: DoubleValidator  { // Restricts input
                        bottom: 0
                        top: 2 // Adjust upper limit as needed
                        decimals: 2 // Set to the number of decimal places you want to allow
                    }
            onTextChanged: {
                    if (_activeVehicle && safetydistm.text !== "") {
                                _activeVehicle.setsafetyval(parseFloat(safetydistm.text))
                            }
                    }
        }
        */

        QGCLabel {
            id: activecentering
            x: 25
            y: 150
            width: 82
            height: 12
            text: qsTr("Active Centering")
            anchors.verticalCenterOffset: -5
            anchors.horizontalCenterOffset: 50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
        }

        QGCCheckBox {
            id : activekalman
            x: 10
            y: 10
            width: 10
            height: 10
            anchors.verticalCenterOffset: -5
            anchors.horizontalCenterOffset: 150
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            onCheckedChanged: {
                        if (_activeVehicle) {
                            // Update based on whether the checkbox is checked or not
                            _activeVehicle.setactivecenter(checked ? 1 : 0)
                        }
                    }


        }

        QGCLabel {
            id: horizontalactivelabel
            x: 25
            y: 150
            width: 82
            height: 12
            text: qsTr("Horizontal")
            anchors.verticalCenterOffset: 14
            anchors.horizontalCenterOffset: 50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
        }

        QGCCheckBox {
            id : horizontalactive
            x: 10
            y: 10
            width: 10
            height: 10
            anchors.verticalCenterOffset: 14
            anchors.horizontalCenterOffset: 150
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            onCheckedChanged: {
                        if (_activeVehicle) {
                            // Update based on whether the checkbox is checked or not
                            _activeVehicle.sethorizontal(checked ? 1 : 0)
                        }
                    }
        }


        QGCLabel {
            id: verticallabel
            x: 25
            y: 150
            width: 82
            height: 12
            text: qsTr("Vertical")
            anchors.verticalCenterOffset: 33
            anchors.horizontalCenterOffset: 50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
        }

        QGCCheckBox {
            id : verticalactive
            x: 10
            y: 10
            width: 10
            height: 10
            anchors.verticalCenterOffset: 33
            anchors.horizontalCenterOffset: 150
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            onCheckedChanged: {
                        if (_activeVehicle) {
                            // Update based on whether the checkbox is checked or not
                            _activeVehicle.setvertical(checked ? 1 : 0)
                        }
                    }
        }

        QGCLabel {
            id: thresholdlabel
            x: 25
            y: 150
            width: 82
            height: 12
            text: qsTr("CenterThr (m)")
            anchors.verticalCenterOffset: 55
            anchors.horizontalCenterOffset: -30
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
        }

        QGCTextField {
            id: centerthreshold
            x: 257
            y: 150
            width: 30
            height: 22

            text: qsTr("0.1") // RYY

            visible: true
            anchors.verticalCenterOffset: 55
            anchors.horizontalCenterOffset: 50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            selectByMouse: true
            font.pixelSize: 12
            inputMethodHints: Qt.ImhDigitsOnly // Ensures only digits are accepted RYY
                    validator: DoubleValidator  { // Restricts input
                        bottom: 0
                        top: 2 // Adjust upper limit as needed
                        decimals: 2 // Set to the number of decimal places you want to allow
                    }
            onTextChanged: {
                    if (_activeVehicle && centerthreshold.text !== "") {
                                _activeVehicle.setthresholdval(parseFloat(centerthreshold.text))
                            }
                    }

            QGCButton{
                id: increasethr
                x: 0
                y: 0
                width: 15
                height: 15
                text: qsTr("+")
                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: 30
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                        var currentValue = parseFloat(centerthreshold.text);
                        var newValue = currentValue + 0.1;
                        if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                            newValue = 2;
                        }
                        centerthreshold.text = newValue.toFixed(1);
                    }



            }

            QGCButton{
                id: decreasethr
                x: 0
                y: 0
                width: 15
                height: 15
                text: qsTr("-")
                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: 50
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                        var currentValue = parseFloat(centerthreshold.text);
                        var newValue = currentValue - 0.1;
                        if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                            newValue = 2;
                        }
                        centerthreshold.text = newValue.toFixed(1);
                    }



            }
        }

        QGCLabel {
            id: altimeterlabel
            x: 25
            y: 150
            width: 82
            height: 12
            text: qsTr("Front Altimeter")
            anchors.verticalCenterOffset: -5
            anchors.horizontalCenterOffset: -147
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
        }

        QGCCheckBox {
            id : altimeteractive
            x: 10
            y: 8
            anchors.verticalCenterOffset: -5
            anchors.horizontalCenterOffset: -50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            onCheckedChanged: {
                        if (_activeVehicle) {
                            // Update based on whether the checkbox is checked or not
                            _activeVehicle.setaltimeter(checked ? 1 : 0)
                        }
                    }
        }


        QGCLabel {
            id: activateprofilinglabel
            x: 25
            y: 150
            width: 82
            height: 12
            text: qsTr("Rear Altimeter")
            anchors.verticalCenterOffset: 12
            anchors.horizontalCenterOffset: -147
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
        }


        QGCCheckBox {
            id : profilingactive
            x: 10
            y: 8
            anchors.verticalCenterOffset: 12
            anchors.horizontalCenterOffset: -50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            onCheckedChanged: {
                        if (_activeVehicle) {
                            // Update based on whether the checkbox is checked or not
                            _activeVehicle.setprofiling(checked ? 1 : 0)
                        }
                    }
        }



        QGCLabel {
            id: activeyawtxt
            x: 25
            y: 150
            width: 82
            height: 12
            text: qsTr("Active Yaw Control")
            anchors.verticalCenterOffset: 30
            anchors.horizontalCenterOffset: -147
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13

            // 20 50
        }


        QGCCheckBox {
            id : activeyaw
            x: 10
            y: 8
            anchors.verticalCenterOffset: 30
            anchors.horizontalCenterOffset: -50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            onCheckedChanged: {
                        if (_activeVehicle) {
                            // Update based on whether the checkbox is checked or not
                            _activeVehicle.setactiveyaw(checked ? 1 : 0)
                        }
                    }

        //20 150

        }



        Rectangle {
            id : r2
            width: 391
            height: 202
            radius: 5

            color : "#66060602"
            border.width: 1
            border.color: "#80ffffff"

            anchors.left: parent.left
            anchors.leftMargin: 0
            anchors.top: parent.top
            anchors.topMargin: 150
            QGCLabel {
                id: staltimaterlabel
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("Front Altimeter:")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: -80
                anchors.horizontalCenterOffset: -140
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            GroupBox {
                x: 46
                y: 137
                width: 174
                height: 60

                anchors.verticalCenterOffset: -64
                anchors.horizontalCenterOffset: 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                QGCLabel {
                    id: distTop
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("TOP")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 2
                    anchors.horizontalCenterOffset: -60
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }


                QGCLabel {

                    id: distancetop1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Distance:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -11
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        id: topdistanceM
                        x: 2
                        y: 2
                        width: 15
                        height: 15
                        text: qsTr(_activeVehicle ? _activeVehicle.topAltM1.toFixed(2) : "N/A")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.NoWrap
                    }
                }

                QGCLabel {
                    id: confidencetop1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Confidence:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 15
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        id: topconfidenceM
                        x: 2
                        y: 2
                        width: 15
                        height: 15
                        text: qsTr(_activeVehicle ? _activeVehicle.topConfiM1 + " %" : "N/A")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.NoWrap
                    }
                }



            }

            GroupBox {
                x: 48
                y: 129
                width: 174
                height: 60
                anchors.verticalCenterOffset: 66
                anchors.horizontalCenterOffset: 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                QGCLabel {
                    id: bottomlabel
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("DOWN")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 2
                    anchors.horizontalCenterOffset: -60
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                QGCLabel {
                    id: distancebottom1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Distance:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -11
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        id: bottomdistanceM
                        x: 2
                        y: 2
                        width: 15
                        height: 15
                        text: qsTr(_activeVehicle ? _activeVehicle.downAltM1.toFixed(2) : "N/A")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.NoWrap
                    }

                }


                QGCLabel {
                    id: bottomconfidence1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Confidence:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 15
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        id: bottomconfidenceM
                        x: 2
                        y: 2
                        width: 15
                        height: 15
                        text: qsTr(_activeVehicle ? _activeVehicle.downConfiM1 + " %" : "N/A")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.NoWrap
                    }
                }


            }

            GroupBox {
                x: 46
                y: 137
                width: 174
                height: 60

                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: -101
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter


                QGCLabel {
                    id: distTest
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("LEFT")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 2
                    anchors.horizontalCenterOffset: -60
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                QGCLabel {
                    id: distanceleft1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Distance:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -11
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        id: leftdistanceM
                        x: 2
                        y: 2
                        width: 15
                        height: 15
                        text: qsTr(_activeVehicle ? _activeVehicle.leftAltM1.toFixed(2) : "N/A")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.NoWrap
                    }
                }

                QGCLabel {
                    id: leftconfidence1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Confidence:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 15
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        id: leftconfidenceM
                        x: 2
                        y: 2
                        width: 15
                        height: 15
                        text: qsTr(_activeVehicle ? _activeVehicle.leftConfiM1 + " %" : "N/A")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.NoWrap
                    }
                }

            }


            GroupBox {
                x: 44
                y: 138
                width: 174
                height: 60
                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: 100
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter


                QGCLabel {
                    id: distRight
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("RIGHT")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 2
                    anchors.horizontalCenterOffset: -60
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                QGCLabel {
                    id: distanceright1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Distance:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -11
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        id: rightdistanceM
                        x: 2
                        y: 2
                        width: 15
                        height: 15
                        text: qsTr(_activeVehicle ? _activeVehicle.rightAltM1.toFixed(2) : "N/A")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.NoWrap
                    }
                }

                QGCLabel {
                    id: rightconfidence1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Confidence:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 15
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                    QGCLabel {
                        id: rightconfidenceM
                        x: 2
                        y: 2
                        width: 15
                        height: 15
                        text: qsTr(_activeVehicle ? _activeVehicle.rightConfiM1 + " %" : "N/A")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.NoWrap
                    }
                }
            }
        }

        Rectangle{
        id: rec2ndaltimeter
        x: 47
        width: 391
        height: 202
        color : "#66060602"
        border.width: 1
        border.color: "#80ffffff"
        radius: 5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 355
        anchors.horizontalCenterOffset: 0


        QGCLabel {
            id: secondaltimaterlabel
            x: 26
            y: 168
            width: 65
            height: 20
            text: qsTr("Rear Altimeter:")
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenterOffset: -80
            anchors.horizontalCenterOffset: -140
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
        GroupBox {
            x: 46
            y: 137
            width: 174
            height: 60

            anchors.verticalCenterOffset: -64
            anchors.horizontalCenterOffset: 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            QGCLabel {
                id: distToplabel2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("TOP")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: 2
                anchors.horizontalCenterOffset: -60
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }


            QGCLabel {

                id: distancetop2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("Distance:")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: -11
                anchors.horizontalCenterOffset: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id: topdistanceM2
                    x: 2
                    y: 2
                    width: 15
                    height: 15
                    text: qsTr(_activeVehicle ? _activeVehicle.topAltM1.toFixed(2) : "N/A")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                    anchors.verticalCenterOffset: -2
                    anchors.horizontalCenterOffset: 46
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.NoWrap
                }
            }

            QGCLabel {
                id: confidencetoplabel2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("Confidence:")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: 15
                anchors.horizontalCenterOffset: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id: topconfidenceM2
                    x: 2
                    y: 2
                    width: 15
                    height: 15
                    text: qsTr(_activeVehicle ? _activeVehicle.topConfiM1 + " %" : "N/A")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                    anchors.verticalCenterOffset: -2
                    anchors.horizontalCenterOffset: 46
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.NoWrap
                }
            }



        }

        GroupBox {
            x: 48
            y: 129
            width: 174
            height: 60
            anchors.verticalCenterOffset: 66
            anchors.horizontalCenterOffset: 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            QGCLabel {
                id: bottomlabel2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("DOWN")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: 2
                anchors.horizontalCenterOffset: -60
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            QGCLabel {
                id: distancebottom2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("Distance:")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: -11
                anchors.horizontalCenterOffset: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id: bottomdistanceM2
                    x: 2
                    y: 2
                    width: 15
                    height: 15
                    text: qsTr(_activeVehicle ? _activeVehicle.downAltM1.toFixed(2) : "N/A")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                    anchors.verticalCenterOffset: -2
                    anchors.horizontalCenterOffset: 46
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.NoWrap
                }

            }


            QGCLabel {
                id: bottomconfidence2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("Confidence:")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: 15
                anchors.horizontalCenterOffset: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id: bottomconfidenceM2
                    x: 2
                    y: 2
                    width: 15
                    height: 15
                    text: qsTr(_activeVehicle ? _activeVehicle.downConfiM1 + " %" : "N/A")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                    anchors.verticalCenterOffset: -2
                    anchors.horizontalCenterOffset: 46
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.NoWrap
                }
            }


        }

        GroupBox {
            x: 46
            y: 137
            width: 174
            height: 60

            anchors.verticalCenterOffset: 0
            anchors.horizontalCenterOffset: -101
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter


            QGCLabel {
                id: distTest2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("LEFT")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: 2
                anchors.horizontalCenterOffset: -60
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            QGCLabel {
                id: distanceleft2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("Distance:")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: -11
                anchors.horizontalCenterOffset: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id: leftdistanceM2
                    x: 2
                    y: 2
                    width: 15
                    height: 15
                    text: qsTr(_activeVehicle ? _activeVehicle.leftAltM1.toFixed(2) : "N/A")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                    anchors.verticalCenterOffset: -2
                    anchors.horizontalCenterOffset: 46
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.NoWrap
                }
            }

            QGCLabel {
                id: leftconfidence2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("Confidence:")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: 15
                anchors.horizontalCenterOffset: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id: leftconfidenceM2
                    x: 2
                    y: 2
                    width: 15
                    height: 15
                    text: qsTr(_activeVehicle ? _activeVehicle.leftConfiM1 + " %" : "N/A")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                    anchors.verticalCenterOffset: -2
                    anchors.horizontalCenterOffset: 46
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.NoWrap
                }
            }

        }


        GroupBox {
            x: 44
            y: 138
            width: 174
            height: 60
            anchors.verticalCenterOffset: 0
            anchors.horizontalCenterOffset: 100
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter


            QGCLabel {
                id: distRight2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("RIGHT")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: 2
                anchors.horizontalCenterOffset: -60
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            QGCLabel {
                id: distanceright2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("Distance:")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: -11
                anchors.horizontalCenterOffset: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id: rightdistanceM2
                    x: 2
                    y: 2
                    width: 15
                    height: 15
                    text: qsTr(_activeVehicle ? _activeVehicle.rightAltM1.toFixed(2) : "N/A")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                    anchors.verticalCenterOffset: -2
                    anchors.horizontalCenterOffset: 46
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.NoWrap
                }
            }

            QGCLabel {
                id: rightconfidence2
                x: 26
                y: 168
                width: 65
                height: 20
                text: qsTr("Confidence:")
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenterOffset: 15
                anchors.horizontalCenterOffset: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id: rightconfidenceM2
                    x: 2
                    y: 2
                    width: 15
                    height: 15
                    text: qsTr(_activeVehicle ? _activeVehicle.rightConfiM1 + " %" : "N/A")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                    anchors.verticalCenterOffset: -2
                    anchors.horizontalCenterOffset: 46
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.NoWrap
                }
            }
        }

        }


        Rectangle {
            id: recINS
            x: 47
            width: 391
            height: 30
            color: "#30060333"
            radius: 5
            border.width: 1
            border.color: "#ffffff"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 565
            anchors.horizontalCenterOffset: 0

            QGCLabel {
                id: txtINS
                x: 27
                width: 82
                height: 20
                text: qsTr("INS -->")
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 10
                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: -150
            }


            QGCLabel {
                id: speedins
                x: 10
                y: 10
                width: 82
                height: 12
                text: qsTr("Speed : ")
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 10
                anchors.verticalCenterOffset: -5
                anchors.horizontalCenterOffset: 0
                QGCLabel {
                    id: speedinsm
                    x: 10
                    y: 10
                    width: 82
                    height: 12
                    text: qsTr(_activeVehicle ? _activeVehicle.speedM1 + " %" : "N/A")
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    font.pointSize: 10
                    anchors.verticalCenterOffset: 0
                    anchors.horizontalCenterOffset: 50
                }
            }


        }

        Rectangle{
            id : r5
            width: 391
            height: 202
            radius: 5
            color : "#66060602"


            anchors.left: parent.left
            anchors.leftMargin: 0

            anchors.top: parent.top
            anchors.topMargin: 600
            anchors.horizontalCenterOffset: 0

            QGCLabel{
                id: txtoffset
                x: 27
                width: 82
                height: 20
                text: qsTr("Offset -->")
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 10
                anchors.verticalCenterOffset: -50
                anchors.horizontalCenterOffset: -150

            }

            GroupBox{
                x: 46
                y: 137
                width: 174
                height: 60

                anchors.verticalCenterOffset: -64
                anchors.horizontalCenterOffset: 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                QGCLabel {
                    id: offsetTop
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("TOP")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 2
                    anchors.horizontalCenterOffset: -60
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                }


                QGCLabel{
                    id: offsettop1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Distance(m):")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -11
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter


                    QGCTextField {
                        id: offsettopval
                        x: 257
                        y: 150
                        width: 30
                        height: 22

                        text: qsTr("0.1") // RYY

                        visible: true
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 50
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true
                        font.pixelSize: 12


                        inputMethodHints: Qt.ImhDigitsOnly // Ensures only digits are accepted RYY
                                validator: DoubleValidator  { // Restricts input
                                    bottom: 0
                                    top: 5 // Adjust upper limit as needed
                                    decimals: 2 // Set to the number of decimal places you want to allow
                                }
                        onTextChanged: {
                                if (_activeVehicle && offsettopval.text !== "") {
                                            _activeVehicle.topoffset(parseFloat(offsettopval.text))
                                        }
                                }

                        QGCButton{
                            id: increasetopoff
                            x: 0
                            y: 0
                            width: 15
                            height: 15
                            text: qsTr("+")
                            anchors.verticalCenterOffset: 0
                            anchors.horizontalCenterOffset: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                    var currentValue = parseFloat(offsettopval.text);
                                    var newValue = currentValue + 0.1;
                                    if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                                        newValue = 2;
                                    }
                                    offsettopval.text = newValue.toFixed(1);
                                }



                        }

                        QGCButton{
                            id: decreasetopoff
                            x: 0
                            y: 0
                            width: 15
                            height: 15
                            text: qsTr("-")
                            anchors.verticalCenterOffset: 20
                            anchors.horizontalCenterOffset: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                    var currentValue = parseFloat(offsettopval.text);
                                    var newValue = currentValue - 0.1;
                                    if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                                        newValue = 2;
                                    }
                                    offsettopval.text = newValue.toFixed(1);
                                }



                        }
                    }


                }

                QGCLabel {
                    id: activeoffset1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Active:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 15
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter


                    QGCCheckBox {
                        id : activetopoffsetcheck
                        x: 10
                        y: 8
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        onCheckedChanged: {
                                    if (_activeVehicle) {
                                        // Update based on whether the checkbox is checked or not
                                        _activeVehicle.activetopoffset(checked ? 1 : 0)
                                    }
                                }
                    }
                }



            }



            GroupBox{
                x: 46
                y: 137
                width: 174
                height: 60

                anchors.verticalCenterOffset: 66
                anchors.horizontalCenterOffset: 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                QGCLabel {
                    id: bottomlabel1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("DOWN")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 2
                    anchors.horizontalCenterOffset: -60
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                }


                QGCLabel{
                    id: offsetdown1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Distance(m):")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -11
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter


                    QGCTextField {
                        id: offsetdownval
                        x: 257
                        y: 150
                        width: 30
                        height: 22

                        text: qsTr("0.1") // RYY

                        visible: true
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 50
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true
                        font.pixelSize: 12


                        inputMethodHints: Qt.ImhDigitsOnly // Ensures only digits are accepted RYY
                                validator: DoubleValidator  { // Restricts input
                                    bottom: 0
                                    top: 5 // Adjust upper limit as needed
                                    decimals: 2 // Set to the number of decimal places you want to allow
                                }
                        onTextChanged: {
                                if (_activeVehicle && offsetdownval.text !== "") {
                                            _activeVehicle.downoffset(parseFloat(offsetdownval.text))
                                        }
                                }

                        QGCButton{
                            id: increasedownoff
                            x: 0
                            y: 0
                            width: 15
                            height: 15
                            text: qsTr("+")
                            anchors.verticalCenterOffset: 0
                            anchors.horizontalCenterOffset: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                    var currentValue = parseFloat(offsetdownval.text);
                                    var newValue = currentValue + 0.1;
                                    if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                                        newValue = 2;
                                    }
                                    offsetdownval.text = newValue.toFixed(1);
                                }



                        }

                        QGCButton{
                            id: decreasedownoff
                            x: 0
                            y: 0
                            width: 15
                            height: 15
                            text: qsTr("-")
                            anchors.verticalCenterOffset: 20
                            anchors.horizontalCenterOffset: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                    var currentValue = parseFloat(offsetdownval.text);
                                    var newValue = currentValue - 0.1;
                                    if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                                        newValue = 2;
                                    }
                                    offsetdownval.text = newValue.toFixed(1);
                                }



                        }

                    }


                }

                QGCLabel {
                    id: activeoffset2
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Active:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 15
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter


                    QGCCheckBox {
                        id : activedownoffsetcheck2
                        x: 10
                        y: 8
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter

                        onCheckedChanged: {
                                    if (_activeVehicle) {
                                        // Update based on whether the checkbox is checked or not
                                        _activeVehicle.activedownoffset(checked ? 1 : 0)
                                    }
                                }

                    }
                }



            }

            GroupBox{
                x: 46
                y: 137
                width: 174
                height: 60

                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: -101
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                QGCLabel {
                    id: offsetlefttxt
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("LEFT")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 2
                    anchors.horizontalCenterOffset: -60
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                }


                QGCLabel{
                    id: offsetleft
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Distance(m):")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -11
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter


                    QGCTextField {
                        id: offsetleftval
                        x: 257
                        y: 150
                        width: 30
                        height: 22

                        text: qsTr("0.1") // RYY

                        visible: true
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 50
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true
                        font.pixelSize: 12

                        inputMethodHints: Qt.ImhDigitsOnly // Ensures only digits are accepted RYY
                                validator: DoubleValidator  { // Restricts input
                                    bottom: 0
                                    top: 5 // Adjust upper limit as needed
                                    decimals: 2 // Set to the number of decimal places you want to allow
                                }
                        onTextChanged: {
                                if (_activeVehicle && offsetleftval.text !== "") {
                                            _activeVehicle.leftoffset(parseFloat(offsetleftval.text))
                                        }
                                }

                        QGCButton{
                            id: increaseleftnoff
                            x: 0
                            y: 0
                            width: 15
                            height: 15
                            text: qsTr("+")
                            anchors.verticalCenterOffset: 0
                            anchors.horizontalCenterOffset: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                    var currentValue = parseFloat(offsetleftval.text);
                                    var newValue = currentValue + 0.1;
                                    if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                                        newValue = 2;
                                    }
                                    offsetleftval.text = newValue.toFixed(1);
                                }



                        }

                        QGCButton{
                            id: decreaseleftoff
                            x: 0
                            y: 0
                            width: 15
                            height: 15
                            text: qsTr("-")
                            anchors.verticalCenterOffset: 20
                            anchors.horizontalCenterOffset: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                    var currentValue = parseFloat(offsetleftval.text);
                                    var newValue = currentValue - 0.1;
                                    if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                                        newValue = 2;
                                    }
                                    offsetleftval.text = newValue.toFixed(1);
                                }



                        }

                    }


                }

                QGCLabel {
                    id: activeoffsetleft
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Active:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 15
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter


                    QGCCheckBox {
                        id : activeoffsetleftval
                        x: 10
                        y: 8
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter

                        onCheckedChanged: {
                                    if (_activeVehicle) {
                                        // Update based on whether the checkbox is checked or not
                                        _activeVehicle.activeleftoffset(checked ? 1 : 0)
                                    }
                                }
                    }
                }



            }

            GroupBox{
                x: 46
                y: 137
                width: 174
                height: 60

                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: 100
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                QGCLabel {
                    id: distRight1
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("RIGHT")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 2
                    anchors.horizontalCenterOffset: -60
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                }


                QGCLabel{
                    id: offsetright
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Distance(m):")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -11
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter


                    QGCTextField {
                        id: offsetrightval
                        x: 257
                        y: 150
                        width: 30
                        height: 22

                        text: qsTr("0.1") // RYY

                        visible: true
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 50
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true
                        font.pixelSize: 12

                        inputMethodHints: Qt.ImhDigitsOnly // Ensures only digits are accepted RYY
                                validator: DoubleValidator  { // Restricts input
                                    bottom: 0
                                    top: 5 // Adjust upper limit as needed
                                    decimals: 2 // Set to the number of decimal places you want to allow
                                }
                        onTextChanged: {
                                if (_activeVehicle && offsetrightval.text !== "") {
                                            _activeVehicle.rightoffset(parseFloat(offsetrightval.text))
                                        }
                                }

                        QGCButton{
                            id: increaserightnoff
                            x: 0
                            y: 0
                            width: 15
                            height: 15
                            text: qsTr("+")
                            anchors.verticalCenterOffset: 0
                            anchors.horizontalCenterOffset: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                    var currentValue = parseFloat(offsetrightval.text);
                                    var newValue = currentValue + 0.1;
                                    if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                                        newValue = 2;
                                    }
                                    offsetrightval.text = newValue.toFixed(1);
                                }



                        }

                        QGCButton{
                            id: decreasetightoff
                            x: 0
                            y: 0
                            width: 15
                            height: 15
                            text: qsTr("-")
                            anchors.verticalCenterOffset: 20
                            anchors.horizontalCenterOffset: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                    var currentValue = parseFloat(offsetrightval.text);
                                    var newValue = currentValue - 0.1;
                                    if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                                        newValue = 2;
                                    }
                                    offsetrightval.text = newValue.toFixed(1);
                                }



                        }


                    }


                }

                QGCLabel {
                    id: activeoffsetright
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Active:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 15
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter


                    QGCCheckBox {
                        id : activeoffsetrightval
                        x: 10
                        y: 8
                        anchors.verticalCenterOffset: -2
                        anchors.horizontalCenterOffset: 46
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter


                        onCheckedChanged: {
                                    if (_activeVehicle) {
                                        // Update based on whether the checkbox is checked or not
                                        _activeVehicle.activerightoffset(checked ? 1 : 0)
                                    }
                                }
                    }
                }



            }

            Rectangle{
                id : r9
                width: 391
                height: 202
                radius: 5
                color : "#66060602"


                anchors.left: parent.left
                anchors.leftMargin: 0

                anchors.top: parent.top
                anchors.topMargin: 210
                anchors.horizontalCenterOffset: 0

                QGCLabel {
                    id: cruiselabel
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("<-- Cruise speed control (m/s) -->")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -80
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                QGCSlider {
                    id:                         cruise
                    height:                     150
                    width:                      350
                    orientation:                Qt.Horizontal
                    minimumValue:               0
                    maximumValue:               10
                    stepSize:                   1
                    value:                      0
                    anchors.verticalCenterOffset: -60
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter


                    onValueChanged: {
                        if (_activeVehicle) {
                            // Update based on whether the checkbox is checked or not
                            _activeVehicle.setsafetyval(parseFloat(cruise.value))
                        }
                    }
                }

                QGCLabel {
                    id: cruiseval
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: cruise.value
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -40
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }


                QGCLabel {
                    id: actcruiselabel
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Active:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -20
                    anchors.horizontalCenterOffset: -70
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    QGCCheckBox {
                        id : actcruiseval
                        x: 10
                        y: 8
                        anchors.verticalCenterOffset: 0
                        anchors.horizontalCenterOffset: 30
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter


                        onCheckedChanged: {
                                    if (_activeVehicle) {
                                        // Update based on whether the checkbox is checked or not
                                        _activeVehicle.activecruise(checked ? 1 : 0)
                                    }
                                }
                    }
                }


                QGCLabel {
                    id: actcruisebackwardlabel
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Backward:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: -20
                    anchors.horizontalCenterOffset: 30
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    QGCCheckBox {
                        id : actcruisebackward
                        x: 10
                        y: 8
                        anchors.verticalCenterOffset: 0
                        anchors.horizontalCenterOffset: 40
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter


                        onCheckedChanged: {
                                    if (_activeVehicle) {
                                        // Update based on whether the checkbox is checked or not
                                        _activeVehicle.activebackward(checked ? 1 : 0)
                                    }
                                }
                    }
                }

                QGCLabel {
                    id: calibrationmodelabel
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Calibration:")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 10
                    anchors.horizontalCenterOffset: -100
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    QGCCheckBox {
                        id : calibarationmodeactive
                        x: 10
                        y: 8
                        anchors.verticalCenterOffset: 0
                        anchors.horizontalCenterOffset: 50
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter


                        onCheckedChanged: {
                                    if (_activeVehicle) {
                                        // Update based on whether the checkbox is checked or not
                                        _activeVehicle.sethorizontal(checked ? 2 : 0)
                                    }
                                }
                    }
                }

                QGCLabel{
                    id: altitudecalib
                    x: 26
                    y: 168
                    width: 65
                    height: 20
                    text: qsTr("Altitude(m):")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenterOffset: 10
                    anchors.horizontalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter


                    QGCTextField {
                        id: altitudecalibinpt
                        x: 257
                        y: 150
                        width: 30
                        height: 22

                        text: qsTr("0.1") // RYY

                        visible: true
                        anchors.verticalCenterOffset: 0
                        anchors.horizontalCenterOffset: 50
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true
                        font.pixelSize: 12


                        inputMethodHints: Qt.ImhDigitsOnly // Ensures only digits are accepted RYY
                                validator: DoubleValidator  { // Restricts input
                                    bottom: 0
                                    top: 5 // Adjust upper limit as needed
                                    decimals: 2 // Set to the number of decimal places you want to allow
                                }
                        onTextChanged: {
                                if (_activeVehicle && altitudecalibinpt.text !== "") {
                                            _activeVehicle.setcalibval(parseFloat(altitudecalibinpt.text))
                                        }
                                }

                        QGCButton{
                            id: increasealtitude
                            x: 0
                            y: 0
                            width: 15
                            height: 15
                            text: qsTr("+")
                            anchors.verticalCenterOffset: -10
                            anchors.horizontalCenterOffset: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                    var currentValue = parseFloat(altitudecalibinpt.text);
                                    var newValue = currentValue + 0.1;
                                    if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                                        newValue = 2;
                                    }
                                    altitudecalibinpt.text = newValue.toFixed(1);
                                }



                        }

                        QGCButton{
                            id: decreasealtitude
                            x: 0
                            y: 0
                            width: 15
                            height: 15
                            text: qsTr("-")
                            anchors.verticalCenterOffset: 10
                            anchors.horizontalCenterOffset: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                    var currentValue = parseFloat(altitudecalibinpt.text);
                                    var newValue = currentValue - 0.1;
                                    if (newValue > 2) { // Ensure it does not exceed the maximum value of the validator
                                        newValue = 2;
                                    }
                                    altitudecalibinpt.text = newValue.toFixed(1);
                                }



                        }
                    }


                }



            }







        }





    }




    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function showCriticalVehicleMessage(message) {
        indicatorPopup.close()
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional wanring message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.dropMessageIndicatorOnClose = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = message
            criticalVehicleMessagePopup.dropMessageIndicatorOnClose = false
            criticalVehicleMessagePopup.open()
        }
    }

    Popup {
        id:                 criticalVehicleMessagePopup
        y:                  ScreenTools.defaultFontPixelHeight
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal:              false
        focus:              true
        closePolicy:        Popup.CloseOnEscape

        property alias  criticalVehicleMessage:        criticalVehicleMessageText.text
        property bool   dropMessageIndicatorOnClose:   false

        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      vehicleWarningLabel.contentWidth + _margins
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Vehicle Error")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            Rectangle {
                id:                         additionalErrorsIndicator
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.bottom:             parent.bottom
                anchors.bottomMargin:       -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      additionalErrorsLabel.contentWidth + _margins
                height:                     additionalErrorsLabel.contentHeight + _margins
                visible:                    criticalVehicleMessagePopup.dropMessageIndicatorOnClose

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 additionalErrorsLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Additional errors received")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                criticalVehicleMessagePopup.close()
                if (criticalVehicleMessagePopup.dropMessageIndicatorOnClose) {
                    criticalVehicleMessagePopup.dropMessageIndicatorOnClose = false;
                    QGroundControl.multiVehicleManager.activeVehicle.resetErrorLevelMessages();
                    toolbar.dropMessageIndicatorTool();
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Indicator Popups

    function showIndicatorPopup(item, dropItem) {
        indicatorPopup.currentIndicator = dropItem
        indicatorPopup.currentItem = item
        indicatorPopup.open()
    }

    function hideIndicatorPopup() {
        indicatorPopup.close()
        indicatorPopup.currentItem = null
        indicatorPopup.currentIndicator = null
    }

    Popup {
        id:             indicatorPopup
        padding:        ScreenTools.defaultFontPixelWidth * 0.75
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property var    currentItem:        null
        property var    currentIndicator:   null
        background: Rectangle {
            width:  loader.width
            height: loader.height
            color:  Qt.rgba(0,0,0,0)
        }
        Loader {
            id:             loader
            onLoaded: {
                var centerX = mainWindow.contentItem.mapFromItem(indicatorPopup.currentItem, 0, 0).x - (loader.width * 0.5)
                if((centerX + indicatorPopup.width) > (mainWindow.width - ScreenTools.defaultFontPixelWidth)) {
                    centerX = mainWindow.width - indicatorPopup.width - ScreenTools.defaultFontPixelWidth
                }
                indicatorPopup.x = centerX
            }
        }
        onOpened: {
            loader.sourceComponent = indicatorPopup.currentIndicator
        }
        onClosed: {
            loader.sourceComponent = null
            indicatorPopup.currentIndicator = null
        }
    }

    // We have to create the popup windows for the Analyze pages here so that the creation context is rooted
    // to mainWindow. Otherwise if they are rooted to the AnalyzeView itself they will die when the analyze viewSwitch
    // closes.

    function createrWindowedAnalyzePage(title, source) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.source = source
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    true

            property alias source: loader.source

            Rectangle {
                color:          QGroundControl.globalPalette.window
                anchors.fill:   parent

                Loader {
                    id:             loader
                    anchors.fill:   parent
                    onLoaded:       item.popped = true
                }
            }

            onClosing: {
                visible = false
                source = ""
            }
        }
    }
}
