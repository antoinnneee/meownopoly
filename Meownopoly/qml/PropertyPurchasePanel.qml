import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./style"
import Game

Rectangle {
    id: root
    color: "#34495e"  // Darker blue background
    radius: 8
    
    // Use PropertyController for property functionality
    PropertyController {
        id: propertyController
        
        onPropertyStatusChanged: {
            console.log("Property purchase panel: Status changed - " + 
                        "Is buyable: " + isPropertyBuyable + 
                        ", Name: " + propertyName + 
                        ", Price: " + propertyPrice);
            
            // Update UI based on property status
            propertyNameText.text = propertyName;
            propertyPriceText.text = propertyPrice > 0 ? propertyPrice + " K" : "N/A";
            
            // Only enable buy button if property is buyable and player can afford it
            if (Game.currentPlayerIndex >= 0 && Game.currentPlayerIndex < Game.players.length) {
                let player = Game.players[Game.currentPlayerIndex];
                buyButton.enabled = isPropertyBuyable && player && player.kibble >= propertyPrice;
            } else {
                buyButton.enabled = false;
            }
        }
        
        onPropertyPurchased: function(success) {
            try {
                if (success) {
                    // Successful purchase
                    console.log("Property purchase successful");
                    
                    // Show success message
                    statusText.text = "Purchased!";
                    statusText.color = "#2ecc71";
                    statusText.visible = true;
                    
                    // Hide success message after a delay
                    messageTimer.restart();
                    
                    // Update board state
                    if (gameBoard) {
                        // Try to update the board to show new ownership
                        try {
                            if (gameBoard.boardGridReference && typeof gameBoard.boardGridReference.updateAllTiles === 'function') {
                                gameBoard.boardGridReference.updateAllTiles();
                            }
                        } catch (e) {
                            console.error("Error updating board after purchase:", e);
                        }
                    }
                } else {
                    // Purchase failed
                    console.log("Property purchase failed");
                    
                    // Show error message
                    statusText.text = "Purchase failed!";
                    statusText.color = "#e74c3c";
                    statusText.visible = true;
                    
                    // Hide error message after a delay
                    messageTimer.restart();
                }
                
                // Update property status
                propertyController.updatePropertyStatus();
            } catch (e) {
                console.error("Error handling property purchase result:", e);
            }
        }
    }
    
    // Reference to game board for updates
    property var gameBoard: null
    
    // Status message timer
    Timer {
        id: messageTimer
        interval: 2000  // 2 seconds
        repeat: false
        onTriggered: {
            statusText.visible = false;
        }
    }
    
    // Transaction safety timer
    Timer {
        id: transactionSafetyTimer
        interval: 3000 // 3 seconds
        repeat: false
        onTriggered: {
            // Re-enable buttons after timeout
            buyButton.enabled = propertyController.isPropertyBuyable;
            declineButton.enabled = true;
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        Text {
            text: "Buy Property"
            font.pixelSize: 16
            font.bold: true
            color: "white"
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Property details
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            
            Text {
                id: propertyNameText
                text: propertyController.propertyName
                color: "white"
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                elide: Text.ElideRight
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            
            Text {
                id: propertyPriceText
                text: propertyController.propertyPrice > 0 ? propertyController.propertyPrice + " K" : "N/A"
                color: "#f1c40f"  // Gold
                font.pixelSize: 18
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            
            // Status message (hidden by default)
            Text {
                id: statusText
                text: "Purchased!"
                color: "#2ecc71"  // Green
                font.pixelSize: 14
                font.bold: true
                visible: false
                Layout.alignment: Qt.AlignHCenter
            }
        }
        
        // Button row with separate buy/decline buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Layout.alignment: Qt.AlignHCenter
            
            // Buy button
            GameActionButton {
                id: buyButton
                text: "Buy"
                customColor: "#2ecc71"  // Green
                enabled: propertyController.isPropertyBuyable
                
                onClicked: {
                    try {
                        console.log("Buy button clicked");
                        
                        // Disable buttons to prevent double-clicking
                        buyButton.enabled = false;
                        declineButton.enabled = false;
                        
                        // Start safety timer
                        transactionSafetyTimer.restart();
                        
                        // Attempt to buy property
                        propertyController.buyProperty();
                    } catch (e) {
                        console.error("Error in buy button click handler:", e);
                        
                        // Re-enable buttons in case of error
                        buyButton.enabled = propertyController.isPropertyBuyable;
                        declineButton.enabled = true;
                    }
                }
            }
            
            // Decline button
            GameActionButton {
                id: declineButton
                text: "Decline"
                customColor: "#e74c3c"  // Red
                
                onClicked: {
                    try {
                        console.log("Decline button clicked");
                        
                        // Simply close the dialog when declining
                        if (gameBoard && typeof gameBoard.closePurchaseDialog === 'function') {
                            gameBoard.closePurchaseDialog();
                        }
                    } catch (e) {
                        console.error("Error in decline button click handler:", e);
                    }
                }
            }
        }
    }
    
    Component.onCompleted: {
        try {
            console.log("PropertyPurchasePanel completed");
            // Update property status
            propertyController.updatePropertyStatus();
        } catch (e) {
            console.error("Error in PropertyPurchasePanel onCompleted:", e);
        }
    }
} 
