//
//  Settings.swift
//  K360Player
//
//  Created by Sergey Kim on 09.09.16.
//  Copyright © 2016 Sergey Kim. All rights reserved.
//

import UIKit

struct Settings {
    static var isLocalStorageOn: Bool {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            return defaults.boolForKey("LocalStorage")
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setBool(newValue, forKey: "LocalStorage")
        }
    }
}
