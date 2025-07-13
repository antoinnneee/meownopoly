import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "./style"
import Game

Popup {
    id: root
    width: 250
    height: 250
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    
    // Property controller for managing property functionality
    PropertyController {
        id: propertyController
        
        onPropertyStatusChanged: {
            // Log property status changes for debugging
            console.log("GameActionDialog: Property status changed - " + 
                        "Is buyable: " + isPropertyBuyable + 
                        ", Name: " + propertyName + 
                        ", Price: " + propertyPrice);
                        
            // Only show buy property panel if property is buyable
            buyPropertyPanel.visible = isPropertyBuyable && actionType === "buyProperty";
        }
        
        onPropertyPurchased: function(success) {
            if (success) {
                console.log("Property purchased successfully through dialog");
                // Force update the board to show new ownership
                if (gameBoard && gameBoard.boardGrid) {
                    gameBoard.boardGrid.updateAllTiles();
                }
            }
        }
    }
    
    // Properties
    property var gameBoard: null
    property var boardGridReference: null
    property string actionType: ""  // Controls which action to display: "buyProperty", etc.
    property bool isDialogProcessing: false  // Flag to prevent multiple operations
    
    // Safety timer to reset processing flag if stuck
    Timer {
        id: processingResetTimer
        interval: 5000  // 5 seconds
        repeat: false
        onTriggered: {
            console.warn("Dialog processing flag stuck, forcing reset");
            isDialogProcessing = false;
        }
    }
    
    // Background
    background: Rectangle {
        color: "#34495e"
        radius: 8
        border.color: "#2c3e50"
        border.width: 2
    }
    
    // Main content
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10
        
        PropertyPurchasePanel {
            id: buyPropertyPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: actionType === "buyProperty"
            gameBoard: root.findGameBoard()
        }
        
        // Add other action panels here in the future
    }
    
    // Show the dialog for buying a property with error handling
    function showBuyProperty() {
        try {
            // Prevent showing multiple dialogs
            if (isDialogProcessing) {
                console.warn("GameActionDialog: Dialog already processing, ignoring request");
                return;
            }
            
            // Set processing flag
            isDialogProcessing = true;
            processingResetTimer.restart();
            
            console.log("GameActionDialog: Showing buy property dialog");
            
            // Verify property is actually buyable before showing
            propertyController.updatePropertyStatus();
            
            if (!propertyController.isPropertyBuyable) {
                console.log("GameActionDialog: Property not buyable, not showing dialog");
                isDialogProcessing = false;
                processingResetTimer.stop();
                return;
            }
            
            // Set action type and show dialog
            actionType = "buyProperty";
            
            console.log("GameActionDialog: Popup status before opening - visible: " + 
                        visible + ", opened: " + opened);
                        
            // Pass board reference to the purchase panel
            buyPropertyPanel.gameBoard = findGameBoard();
            
            // Show dialog with slight delay to ensure game state is updated
            openTimer.restart();
        } catch (e) {
            console.error("GameActionDialog: Error showing buy property dialog:", e);
            isDialogProcessing = false;
            processingResetTimer.stop();
        }
    }
    
    // Timer to open dialog after short delay
    Timer {
        id: openTimer
        interval: 200  // 200ms delay
        repeat: false
        onTriggered: {
            try {
                if (!root.opened) {
                    root.open();
                    console.log("GameActionDialog: Opened dialog");
                } else {
                    console.log("GameActionDialog: Dialog already open");
                }
                
                // Clear processing flag now that dialog is shown
                isDialogProcessing = false;
                processingResetTimer.stop();
            } catch (e) {
                console.error("GameActionDialog: Error opening dialog:", e);
                isDialogProcessing = false;
                processingResetTimer.stop();
            }
        }
    }
    
    // Close purchase dialog safely
    function closePurchaseDialog() {
        try {
            console.log("GameActionDialog: Closing purchase dialog");
            root.close();
        } catch (e) {
            console.error("GameActionDialog: Error closing dialog:", e);
        }
    }
    
    // Find game board by traversing parent/object hierarchy
    function findGameBoard() {
        try {
            // First check if we already have a reference
            if (gameBoard) {
                return gameBoard;
            }
            
            // Try to find game board by object name
            let board = Window.window.findChild("gameBoard");
            if (board) {
                console.log("GameActionDialog: Found game board by object name");
                gameBoard = board;
                return board;
            }
            
            console.warn("GameActionDialog: Could not find game board reference");
            return null;
        } catch (e) {
            console.error("GameActionDialog: Error finding game board:", e);
            return null;
        }
    }
    
    Component.onCompleted: {
        try {
            // Find game board reference on initialization
            findGameBoard();
        } catch (e) {
            console.error("GameActionDialog: Error in onCompleted:", e);
        }
    }
    
    // Clean up
    Component.onDestruction: {
        console.log("GameActionDialog: Component being destroyed");
    }
} 
