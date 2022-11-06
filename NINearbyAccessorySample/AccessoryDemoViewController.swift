/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view controller that facilitates the Nearby Interaction Accessory user experience.
*/

import UIKit
import NearbyInteraction
import os.log

// An example messaging protocol for communications between the app and the
// accessory. In your app, modify or extend this enumeration to your app's
// user experience and conform the accessory accordingly.
enum MessageId: UInt8 {
    // Messages from the accessory.
    case accessoryConfigurationData = 0x1
    case accessoryUwbDidStart = 0x2
    case accessoryUwbDidStop = 0x3
    
    // Messages to the accessory.
    case initialize = 0xA
    case configureAndStart = 0xB
    case stop = 0xC
}

class AccessoryDemoViewController: UIViewController {
    var dataChannel = DataCommunicationChannel()

     var niSession = NISession() //This creates the session between the app and the devices
     var niSession2 = NISession()//added this to start another session with another device
    
    var configuration: NINearbyAccessoryConfiguration?
    var accessoryConnected = false
    var connectedAccessoryName: String?
    
    // A mapping from a discovery token to a name.
   var accessoryMap = [NIDiscoveryToken: String]()
    //var accessoryMap2 = [NIDiscoveryToken: String]()
    //A Discorvery token temporarly generates a device-ession indetntifier,valid for the lifetime of the session, the system provies it to your app and you echnage it throught your apps networking layer

    
    let logger = os.Logger(subsystem: "com.example.apple-samplecode.NINearbyAccessorySample", category: "AccessoryDemoViewController")

    @IBOutlet weak var connectionStateLabel: UILabel!
    @IBOutlet weak var uwbStateLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var distanceLabel2: UILabel!
    
    @IBOutlet weak var actionButton: UIButton!
    
    //Added this for a start and stop function, this is seen on the front end
    let btnRun = "Start Session"
    let btnStop = "Stop Session"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set a delegate for session updates from the framework.
        niSession.delegate = self
        
        // Prepare the data communication channel.
        dataChannel.accessoryConnectedHandler = accessoryConnected
        dataChannel.accessoryDisconnectedHandler = accessoryDisconnected
        dataChannel.accessoryDataHandler = accessorySharedData
        dataChannel.start()
        
        /*Adding this to try on for stop and start sessions*/
        actionButton.setTitle(btnRun, for: .normal)
        
        updateInfoLabel(with: "Scanning for accessories")
    }
    //commented this orginal part out
    /*@IBAction func buttonAction(_ sender: Any) {
        
        updateInfoLabel(with: "Requesting configuration data from accessory")
        let msg = Data([MessageId.initialize.rawValue])
        sendDataToAccessory(msg)
    } */
    //Addes this for some addede fucntionality of the stop and start
    @IBAction func buttonAction(_ sender: Any) {
        var msg: Data

        if actionButton.titleLabel!.text == btnRun {
            updateInfoLabel(with: "Requesting configuration data from accessory")
            msg = Data([MessageId.initialize.rawValue])
        } else {
            updateInfoLabel(with: "Requesting accessory to stop")
            msg = Data([MessageId.stop.rawValue])
        }

        sendDataToAccessory(msg)
    }
    
    // MARK: - Data channel methods
    
    func accessorySharedData(data: Data, accessoryName: String) {
        // The accessory begins each message with an identifier byte.
        // Ensure the message length is within a valid range.
        if data.count < 1 {
            updateInfoLabel(with: "Accessory shared data length was less than 1.")
            return
        }
        
        // Assign the first byte which is the message identifier.
        guard let messageId = MessageId(rawValue: data.first!) else {
            fatalError("\(data.first!) is not a valid MessageId.")
        }
        
        // Handle the data portion of the message based on the message identifier.
        switch messageId {
        case .accessoryConfigurationData:
            // Access the message data by skipping the message identifier.
            assert(data.count > 1)
            let message = data.advanced(by: 1)
            setupAccessory(message, name: accessoryName)
        case .accessoryUwbDidStart:
            handleAccessoryUwbDidStart()
        case .accessoryUwbDidStop:
            handleAccessoryUwbDidStop()
        case .configureAndStart:
            fatalError("Accessory should not send 'configureAndStart'.")
        case .initialize:
            fatalError("Accessory should not send 'initialize'.")
        case .stop:
            fatalError("Accessory should not send 'stop'.")
        }
    }
    
    func accessoryConnected(name: String) {
        accessoryConnected = true
        connectedAccessoryName = name
        actionButton.isEnabled = true
        connectionStateLabel.text = "Connected"
        updateInfoLabel(with: "Connected to '\(name)'")
    }
    
    func accessoryDisconnected() {
        accessoryConnected = false
        
        actionButton.setTitle(btnRun, for: .normal)
        actionButton.isEnabled = false
        connectedAccessoryName = nil
        connectionStateLabel.text = "Not Connected"
        updateInfoLabel(with: "Accessory disconnected")
    }
    
    // MARK: - Accessory messages handling
    
    func setupAccessory(_ configData: Data, name: String) {
        updateInfoLabel(with: "Received configuration data from '\(name)'. Running session.")
        do {
            configuration = try NINearbyAccessoryConfiguration(data: configData)
        } catch {
            // Stop and display the issue because the incoming data is invalid.
            // In your app, debug the accessory data to ensure an expected
            // format.
            updateInfoLabel(with: "Failed to create NINearbyAccessoryConfiguration for '\(name)'. Error: \(error)")
            return
        }
        
        // Cache the token to correlate updates with this accessory.
        cacheToken(configuration!.accessoryDiscoveryToken, accessoryName: name)
        niSession.run(configuration!)
        niSession2.run(configuration!)//added this
    }
    
    func handleAccessoryUwbDidStart() {
        updateInfoLabel(with: "Accessory session started.")
        // actionButton.isEnabled = false
        actionButton.setTitle(btnStop, for: .normal)
        actionButton.setTitleColor(UIColor.red, for: .normal)
        self.uwbStateLabel.text = "ON"
    }
    
    func handleAccessoryUwbDidStop() {
        updateInfoLabel(with: "Accessory session stopped.")
       /* if accessoryConnected {
            actionButton.isEnabled = true
        } */
        actionButton.setTitle(btnRun, for: .normal) //added this for function to stop and start button
        actionButton.setTitleColor(UIColor.systemBlue, for: .normal)
        self.uwbStateLabel.text = "OFF"
    }
}

// MARK: - `NISessionDelegate`.

extension AccessoryDemoViewController: NISessionDelegate {

    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {

        guard object.discoveryToken == configuration?.accessoryDiscoveryToken else { return }
        
        // Prepare to send a message to the accessory.
        var msg = Data([MessageId.configureAndStart.rawValue])
        msg.append(shareableConfigurationData)
        
        let str = msg.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Sending shareable configuration bytes: \(str)")
        
        let accessoryName = accessoryMap[object.discoveryToken] ?? "Unknown"
        //let accessoryName2 = accessoryMap2[object.discoveryToken] ?? "Unknown"
        
        // Send the message to the accessory.
        sendDataToAccessory(msg)
        updateInfoLabel(with: "Sent shareable configuration data to '\(accessoryName)'.")
    }
    
    
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let accessory = nearbyObjects.first else { return }
        guard var distance = accessory.distance else { return }
        guard var direction = accessory.direction else { return }
        guard let name = accessoryMap[accessory.discoveryToken] else { return }
       // guard accessoryMap2[accessory.discoveryToken] != nil else { return }//added this
        //Where distance is displayed on the front end
        // Apply a moving average filter to distance and direction
        includeDistance(distance)
        distance = getAvgDistance()

        includeDirection(direction)
        direction = getAvgDirection()
        // Calculates azimuth and elevation from the average result
        let azimuth = Int(90 * azimuth(direction))
        let elevation = Int(90 * elevation(direction))
        
        /*original code
        self.distanceLabel.text = String(format: "'%@' is %0.1f meters away", name, distance)*/
        // Update Label added to show azimuth and elevation
        self.distanceLabel.text = String(format: "\n\n\n\n\n\n\n%0.1f meters away\nAzimuth: %d°\nElevation: %d°\nName: '%@'",distance, azimuth, elevation,name)
        self.distanceLabel.sizeToFit()
        //added this below
       // self.distanceLabel2.text = String(format: "\n\n\n\n\n\n\n%0.1f meters away\nAzimuth: %d°\nElevation: %d°\nName: '%@'",distance, azimuth, elevation,name)
       // self.distanceLabel2.sizeToFit()
        
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Retry the session only if the peer timed out.
        guard reason == .timeout else { return }
        updateInfoLabel(with: "Session with '\(self.connectedAccessoryName ?? "accessory")' timed out.")
        
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }
        
        // Clear the app's accessory state.
        accessoryMap.removeValue(forKey: accessory.discoveryToken)
       // accessoryMap2.removeValue(forKey: accessory.discoveryToken)//added this
        
        // Consult helper function to decide whether or not to retry.
        if shouldRetry(accessory) {
            sendDataToAccessory(Data([MessageId.stop.rawValue]))
            sendDataToAccessory(Data([MessageId.initialize.rawValue]))
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        updateInfoLabel(with: "Session was suspended.")
        let msg = Data([MessageId.stop.rawValue])
        sendDataToAccessory(msg)
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        updateInfoLabel(with: "Session suspension ended.")
        // When suspension ends, restart the configuration procedure with the accessory.
        let msg = Data([MessageId.initialize.rawValue])
        sendDataToAccessory(msg)
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        switch error {
        case NIError.invalidConfiguration:
            // Debug the accessory data to ensure an expected format.
            updateInfoLabel(with: "The accessory configuration data is invalid. Please debug it and try again.")
        case NIError.userDidNotAllow:
            handleUserDidNotAllow()
        default:
            handleSessionInvalidation()
        }
    }
}

// MARK: - Helpers.

extension AccessoryDemoViewController {
    func updateInfoLabel(with text: String) {
        //self.infoLabel.text = text
        self.distanceLabel.sizeToFit()
        logger.info("\(text)")
    }
    
    func sendDataToAccessory(_ data: Data) {
        do {
            try dataChannel.sendData(data)
        } catch {
            updateInfoLabel(with: "Failed to send data to accessory: \(error)")
        }
    }
    
    func handleSessionInvalidation() {
        updateInfoLabel(with: "Session invalidated. Restarting.")
        // Ask the accessory to stop.
        sendDataToAccessory(Data([MessageId.stop.rawValue]))

        // Replace the invalidated session with a new one.
        self.niSession = NISession()
        self.niSession.delegate = self
        
        self.niSession2 = NISession()//added these two line
        self.niSession2.delegate = self

        // Ask the accessory to stop.
        sendDataToAccessory(Data([MessageId.initialize.rawValue]))
    }
    
    func shouldRetry(_ accessory: NINearbyObject) -> Bool {
        if accessoryConnected {
            return true
        }
        return false
    }
    
    func cacheToken(_ token: NIDiscoveryToken, accessoryName: String) {
        accessoryMap[token] = accessoryName
        //accessoryMap2[token] = accessoryName
        
    }
    
    func handleUserDidNotAllow() {
        // Beginning in iOS 15, persistent access state in Settings.
        updateInfoLabel(with: "Nearby Interactions access required. You can change access for NIAccessory in Settings.")
        
        // Create an alert to request the user go to Settings.
        let accessAlert = UIAlertController(title: "Access Required",
                                            message: """
                                            NIAccessory requires access to Nearby Interactions for this sample app.
                                            Use this string to explain to users which functionality will be enabled if they change
                                            Nearby Interactions access in Settings.
                                            """,
                                            preferredStyle: .alert)
        accessAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        accessAlert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: {_ in
            // Navigate the user to the app's settings.
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }))

        // Preset the access alert.
        present(accessAlert, animated: true, completion: nil)
    }
}


//added these functions that were created joe****

var distArray: Array<Float> = Array(repeating: 0, count: 10)
let zeroVector = simd_make_float3(0, 0, 0)
var diretArray: Array<simd_float3> = Array(repeating: zeroVector, count: 10)
var avgDistIndex = 0
var avgDiretIndex = 0

// Provides the azimuth from an argument 3D directional.
func azimuth(_ direction: simd_float3) -> Float {
    return asin(direction.x)
}

// Provides the elevation from the argument 3D directional.
func elevation(_ direction: simd_float3) -> Float {
    return atan2(direction.z, direction.y) + .pi / 2
}

func includeDistance(_ value: Float) {

    distArray[avgDistIndex] = value

    if avgDistIndex < (distArray.count - 1) {
        avgDistIndex += 1
    }
    else {
        avgDistIndex = 0
    }
}

func getAvgDistance() -> Float {
    var sumValue: Float

    sumValue = 0

    for value in distArray {
        sumValue += value
    }

    return Float(sumValue)/Float(distArray.count)
}

func includeDirection(_ value: simd_float3) {

    diretArray[avgDiretIndex] = value

    if avgDiretIndex < (diretArray.count - 1) {
        avgDiretIndex += 1
    }
    else {
        avgDiretIndex = 0
    }
}

func getAvgDirection() -> simd_float3 {
    var sumValue: simd_float3

    sumValue = zeroVector

    for value in diretArray {
        sumValue += value
    }

    return simd_float3(sumValue)/Float(diretArray.count)
}
