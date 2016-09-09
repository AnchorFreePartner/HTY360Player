//
//  URLInputViewController.swift
//  K360Player
//
//  Created by Sergey Kim on 05.09.16.
//  Copyright © 2016 Sergey Kim. All rights reserved.
//

import UIKit

final class URLInputViewController: UIViewController {

    @IBOutlet weak var urlTextView: UITextView!
    @IBOutlet weak var tableView: UITableView!

    var historyItems: [String] {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            return defaults.objectForKey("HistoryItems") as? [String] ?? [String]()
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setObject(newValue, forKey: "HistoryItems")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.urlTextView.text = "http://d8d913s460fub.cloudfront.net/krpanocloud/video/airpano/video-1920x960a.mp4"
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        self.tableView.reloadData()
    }

    @IBAction func startActionSelected(sender: AnyObject) {
        guard let urlString = self.urlTextView.text else {
            return
        }

        if let index = self.historyItems.indexOf(urlString) {
            self.historyItems.removeAtIndex(index)
        }
        self.historyItems.insert(urlString, atIndex: 0)

        let url = NSURL(string: urlString)
        let videoController = HTY360PlayerVC(nibName: "HTY360PlayerVC", bundle: nil, url: url)
        videoController.showBandwith = Settings.isLocalStorageOn
        
        self.presentViewController(videoController, animated: true, completion: nil)
    }
}

extension URLInputViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.historyItems.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        cell.textLabel?.text = self.historyItems[indexPath.row]

        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.urlTextView.text = self.historyItems[indexPath.row]
    }
}
