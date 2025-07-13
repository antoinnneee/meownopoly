import QtQuick
import QtQuick.Controls
import Game

// Central controller for property-related functionality
Item {
    id: root
    
    // Property attributes
    property bool isPropertyBuyable: false
    property int propertyPrice: 0
    property string propertyName: ""
    property int propertyPosition: -1
    property int playerIndex: Game.currentPlayerIndex
    property bool isProcessingPurchase: false
    
    // Safety timer to reset processing state if stuck
    Timer {
        id: processingResetTimer
        interval: 5000  // 5 seconds timeout
        repeat: false
        onTriggered: {
            console.warn("Property purchase process timed out - resetting state");
            isProcessingPurchase = false;
        }
    }
    
    // Signals
    signal propertyPurchased(bool success)
    signal propertyStatusChanged()
    
    // Update the property buyable status based on current player position
    function updatePropertyStatus() {
        try {
            // Safety check for valid game state
            if (Game.players.length === 0 || !Game.players) {
                console.warn("PropertyController: No players available");
                isPropertyBuyable = false;
                propertyName = "";
                propertyPrice = 0;
                propertyPosition = -1;
                propertyStatusChanged();
                return;
            }
            
            // Get current player
            playerIndex = Game.currentPlayerIndex;
            if (playerIndex < 0 || playerIndex >= Game.players.length) {
                console.warn("PropertyController: Invalid player index:", playerIndex);
                isPropertyBuyable = false;
                propertyStatusChanged();
                return;
            }
            
            var player = Game.players[playerIndex];
            if (!player) {
                console.warn("PropertyController: Player is null");
                isPropertyBuyable = false;
                propertyStatusChanged();
                return;
            }
            
            // Get property at player's position
            propertyPosition = player.position;
            if (propertyPosition < 0 || propertyPosition >= Game.boardSize) {
                console.warn("PropertyController: Invalid property position:", propertyPosition);
                isPropertyBuyable = false;
                propertyStatusChanged();
                return;
            }
            
            var boardCase = Game.getCaseAt(propertyPosition);
            if (!boardCase) {
                console.warn("PropertyController: No case at position:", propertyPosition);
                isPropertyBuyable = false;
                propertyStatusChanged();
                return;
            }
            
            // Check if it's a buyable property (type 1 = Rest Area, type 2 = CardBoardBox)
            var isBuyableType = (boardCase.type === 1 || boardCase.type === 2);
            
            if (isBuyableType) {
                // Check if it's already owned
                var isOwned = false;
                
                // Safe property access with type checking
                if (boardCase.type === 1) {
                    try {
                        // Use hasOwnProperty to check if the property exists
                        if (boardCase.hasOwnProperty("owner") && boardCase.owner) {
                            isOwned = true;
                            console.log("PropertyController: Property already owned by:", boardCase.owner);
                        }
                    } catch (e) {
                        console.error("PropertyController: Error checking ownership:", e);
                    }
                }
                
                // Update property details
                propertyName = boardCase.name || "Unknown Property";
                propertyPrice = boardCase.hasOwnProperty("price") ? boardCase.price : 0;
                isPropertyBuyable = !isOwned && propertyPrice > 0;
                
                console.log("PropertyController: Property status updated - " + 
                            "Name: " + propertyName + 
                            ", Price: " + propertyPrice + 
                            ", Buyable: " + isPropertyBuyable);
            } else {
                // Not a buyable property type
                isPropertyBuyable = false;
                propertyName = boardCase.name || "Unknown";
                propertyPrice = 0;
                console.log("PropertyController: Not a buyable property type:", boardCase.type);
            }
        } catch (e) {
            console.error("PropertyController: Error updating property status:", e);
            isPropertyBuyable = false;
            propertyName = "Error";
            propertyPrice = 0;
        }
        
        // Notify that property status has changed
        propertyStatusChanged();
    }
    
    // Buy the current property
    function buyProperty() {
        // Prevent concurrent purchase attempts
        if (isProcessingPurchase) {
            console.warn("PropertyController: Purchase already in progress, ignoring request");
            return;
        }
        
        // Start transaction
        isProcessingPurchase = true;
        processingResetTimer.start();
        
        try {
            console.log("PropertyController: Attempting to buy property at position " + propertyPosition);
            
            // Verify all conditions are still valid
            if (!isPropertyBuyable) {
                console.warn("PropertyController: Property is not buyable");
                propertyPurchased(false);
                isProcessingPurchase = false;
                processingResetTimer.stop();
                return;
            }
            
            // Double-check player can afford it
            if (playerIndex >= 0 && playerIndex < Game.players.length) {
                var player = Game.players[playerIndex];
                if (!player || player.kibble < propertyPrice) {
                    console.warn("PropertyController: Player cannot afford property");
                    propertyPurchased(false);
                    isProcessingPurchase = false;
                    processingResetTimer.stop();
                    return;
                }
            } else {
                console.warn("PropertyController: Invalid player index for purchase");
                propertyPurchased(false);
                isProcessingPurchase = false;
                processingResetTimer.stop();
                return;
            }
            
            // Execute purchase
            var success = Game.buyProperty(playerIndex, propertyPosition);
            console.log("PropertyController: Purchase result: " + (success ? "Success" : "Failed"));
            
            // Update buyable status to false now that it's purchased
            if (success) {
                isPropertyBuyable = false;
                propertyStatusChanged();
            }
            
            // Signal the result
            propertyPurchased(success);
        } catch (e) {
            console.error("PropertyController: Error buying property:", e);
            propertyPurchased(false);
        } finally {
            // End transaction
            isProcessingPurchase = false;
            processingResetTimer.stop();
        }
    }
    
    // Listen for player changes
    Connections {
        target: Game
        
        function onPlayersChanged() {
            // Use a short delay to ensure all player data is updated
            Qt.callLater(updatePropertyStatus);
        }
        
        function onCurrentPlayerIndexChanged() {
            // Use a short delay to ensure current player index is updated
            Qt.callLater(updatePropertyStatus);
        }
        
        function onPropertyPurchased(position, newOwner) {
            // Ensure our local state reflects the new ownership
            Qt.callLater(updatePropertyStatus);
        }
    }
    
    Component.onCompleted: {
        // Initialize property status
        Qt.callLater(updatePropertyStatus);
    }
} 