//
//  SettingsViewController.swift
//  K360Player
//
//  Created by Sergey Kim on 09.09.16.
//  Copyright © 2016 Sergey Kim. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {

    @IBOutlet weak var localStorageSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.localStorageSwitch.on = Settings.isLocalStorageOn
    }
    
    @IBAction func localStorageValueChanged(sender: AnyObject) {
        Settings.isLocalStorageOn = self.localStorageSwitch.on
    }
}
