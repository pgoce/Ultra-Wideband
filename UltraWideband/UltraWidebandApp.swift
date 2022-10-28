//
//  UltraWidebandApp.swift
//  UltraWideband
//
//  Created by Paul Arcos on 10/28/22.
// A view controller that facilitates the Nearby Interaction Accessory user experienceapp

import SwiftUI
import NearbyInteraction
import os.log
import UIKit

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

// Base struct for the feedback array implementing three different feedback levels
struct FeedbackLvl {
    var hummDuration: TimeInterval
    var timerIndexRef: Int
}

class AccessoryViewController: UIViewController {
    
    
    @IBOutlet weak var distance: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        
         distance.text = "Range"

    }
}

/*@main
struct UltraWidebandApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}*/
