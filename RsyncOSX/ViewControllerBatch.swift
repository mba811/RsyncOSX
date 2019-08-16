//
//  ViewControllerBatch.swift
//  RsyncOSXver30
//
//  Created by Thomas Evensen on 25/08/2016.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//
//  swiftlint:disable line_length

import Foundation
import Cocoa

// Dismiss view when rsync error
protocol ReportonandhaltonError: class {
    func reportandhaltonerror()
}

protocol Attributedestring: class {
    func attributedstring(str: String, color: NSColor, align: NSTextAlignment) -> NSMutableAttributedString
}

extension Attributedestring {
    func attributedstring(str: String, color: NSColor, align: NSTextAlignment) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString(string: str)
        let range = (str as NSString).range(of: str)
        attributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
        attributedString.setAlignment(align, range: range)
        return attributedString
    }
}

class ViewControllerBatch: NSViewController, SetDismisser, Abort, SetConfigurations, Setcolor {

    var row: Int?
    var executebatch: ExecuteBatch?
    var diddissappear: Bool = false
    private var remoteinfotask: RemoteinfoEstimation?
    weak var remoteinfotaskDelegate: SetRemoteInfo?
    weak var inprogresscountDelegate: Count?
    var indexinitiated: Int = -1
    var max: Double?
    var batchisrunning: Bool?

    @IBOutlet weak var mainTableView: NSTableView!
    @IBOutlet weak var executeButton: NSButton!
    @IBOutlet weak var abortbutton: NSButton!
    @IBOutlet weak var estimatingbatch: NSProgressIndicator!
    @IBOutlet weak var estimatingbatchlabel: NSTextField!

    // Either abort or close
    @IBAction func abort(_ sender: NSButton) {
        if self.batchisrunning == true || self.remoteinfotask?.stackoftasktobeestimated != nil {
            self.abort()
        }
        self.executebatch!.closeOperation()
        self.executebatch = nil
        if (self.presentingViewController as? ViewControllertabMain) != nil {
            self.dismissview(viewcontroller: self, vcontroller: .vctabmain)
        } else if (self.presentingViewController as? ViewControllertabSchedule) != nil {
            self.dismissview(viewcontroller: self, vcontroller: .vctabmain)
        } else if (self.presentingViewController as? ViewControllerNewConfigurations) != nil {
            self.dismissview(viewcontroller: self, vcontroller: .vctabmain)
        } else if (self.presentingViewController as? ViewControllerCopyFiles) != nil {
            self.dismissview(viewcontroller: self, vcontroller: .vccopyfiles)
        } else if (self.presentingViewController as? ViewControllerSnapshots) != nil {
            self.dismissview(viewcontroller: self, vcontroller: .vcsnapshot)
        } else if (self.presentingViewController as? ViewControllerSsh) != nil {
            self.dismissview(viewcontroller: self, vcontroller: .vcssh)
        } else if (self.presentingViewController as? ViewControllerVerify) != nil {
            self.dismissview(viewcontroller: self, vcontroller: .vcverify)
        } else if (self.presentingViewController as? ViewControllerLoggData) != nil {
            self.dismissview(viewcontroller: self, vcontroller: .vcloggdata)
        }
    }

    // Execute batch
    @IBAction func execute(_ sender: NSButton) {
        self.batchisrunning = true
        self.estimatingbatchlabel.isHidden = true
        self.executebatch!.executebatch()
        self.executeButton.isEnabled = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ViewControllerReference.shared.setvcref(viewcontroller: .vcbatch, nsviewcontroller: self)
        ViewControllerReference.shared.activetab = .vcbatch
        self.mainTableView.delegate = self
        self.mainTableView.dataSource = self
        self.executebatch = ExecuteBatch()
        self.batchisrunning = false
        self.executeButton.isEnabled = true
        self.estimatingbatch.usesThreadedAnimation = true
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard self.diddissappear == false else {
            globalMainQueue.async(execute: { () -> Void in
                self.mainTableView.reloadData()
            })
            return
        }
        self.executeButton.isEnabled = true
        globalMainQueue.async(execute: { () -> Void in
            self.mainTableView.reloadData()
        })
        self.remoteinfotaskDelegate = ViewControllerReference.shared.getvcref(viewcontroller: .vctabmain) as? ViewControllertabMain
        self.remoteinfotask = RemoteinfoEstimation()
        self.remoteinfotaskDelegate?.setremoteinfo(remoteinfotask: self.remoteinfotask)
        self.initiateProgressbar()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.diddissappear = true
    }

    private func initiateProgressbar(progress: NSProgressIndicator, hiddenID: Int) {
        progress.isHidden = false
        if let calculatedNumberOfFiles = self.executebatch?.maxcountintask(hiddenID: hiddenID) {
            progress.maxValue = Double(calculatedNumberOfFiles)
            self.max = Double(calculatedNumberOfFiles)
        }
        progress.minValue = 0
        progress.doubleValue = 0
        progress.startAnimation(self)
    }

    private func updateProgressbar(progress: NSProgressIndicator) {
        let value = Double(self.executebatch?.incount() ?? 0)
        progress.doubleValue = value
    }

    private func initiateProgressbar() {
        if let calculatedNumberOfFiles = self.configurations?.batchQueuecount() {
            guard calculatedNumberOfFiles > 0 else { return }
            self.estimatingbatch.maxValue = Double(calculatedNumberOfFiles)
            self.max = Double(calculatedNumberOfFiles)
        }
        self.estimatingbatch.isHidden = false
        self.estimatingbatchlabel.isHidden = false
        self.estimatingbatch.minValue = 0
        self.estimatingbatch.doubleValue = 0
        self.estimatingbatch.startAnimation(nil)
    }

    private func updateProgressbar() {
        let max = Double(self.configurations?.batchQueuecount() ?? 0)
        let remaining = Double(self.remoteinfotask?.inprogressCount() ?? 0)
        self.estimatingbatch.doubleValue = max - remaining
    }

}

extension ViewControllerBatch: NSTableViewDataSource {
        // Delegate for size of table
        func numberOfRows(in tableView: NSTableView) -> Int {
            return self.executebatch?.configurations?.getbatchlist()?.count ?? 0
    }
}

extension ViewControllerBatch: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard  self.executebatch?.configurations?.getbatchlist() != nil else { return nil }
        guard row < self.executebatch!.configurations!.getbatchlist()!.count else { return nil }
        let object: NSMutableDictionary = (self.executebatch?.configurations!.getbatchlist()![row])!
        let hiddenID = object.value(forKey: "hiddenID") as? Int
        let cellIdentifier: String = tableColumn!.identifier.rawValue
        if cellIdentifier == "percentCellID" {
            if let cell: NSProgressIndicator = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: self) as? NSProgressIndicator {
                if hiddenID == self.executebatch?.hiddenID {
                    if row > self.indexinitiated {
                        self.indexinitiated = row
                        self.initiateProgressbar(progress: cell, hiddenID: hiddenID!)
                    } else {
                        if self.batchisrunning == false { return nil }
                        self.updateProgressbar(progress: cell)
                    }
                    return cell
                } else {
                    return nil
                }
            }
        } else {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = object.value(forKey: cellIdentifier) as? String ?? ""
                return cell
            }
        }
        return nil
    }
}

extension ViewControllerBatch: StartStopProgressIndicator {

    func stop() {
        self.executeButton.isEnabled = true
        self.estimatingbatch.stopAnimation(nil)
        self.estimatingbatch.isHidden = true
        self.estimatingbatchlabel.stringValue = NSLocalizedString("Estimation completed, you can start batch...", comment: "Batch")
        self.estimatingbatchlabel.textColor = setcolor(nsviewcontroller: self, color: .green)
    }

    func start() {
        self.executeButton.isEnabled = false
    }

    func complete() {
        self.executeButton.isEnabled = false
        self.estimatingbatchlabel.isHidden = false
        self.estimatingbatchlabel.stringValue = NSLocalizedString("Batchtasks completed, close view...", comment: "Batch")
        self.estimatingbatchlabel.textColor = setcolor(nsviewcontroller: self, color: .green)
        self.batchisrunning = false
        globalMainQueue.async(execute: { () -> Void in
            self.mainTableView.reloadData()
        })
    }
}

extension ViewControllerBatch: ReportonandhaltonError {
    func reportandhaltonerror() {
        self.abort()
        self.executebatch?.closeOperation()
        self.executebatch = nil
        self.estimatingbatchlabel.stringValue = "Error"
        self.estimatingbatchlabel.textColor = setcolor(nsviewcontroller: self, color: .red)
    }
}

extension ViewControllerBatch: UpdateProgress {
    func processTermination() {
        if self.batchisrunning == false {
            self.updateProgressbar()
        }
        globalMainQueue.async(execute: { () -> Void in
            self.mainTableView.reloadData()
        })
    }

    func fileHandler() {
        globalMainQueue.async(execute: { () -> Void in
            self.mainTableView.reloadData()
        })
    }
}
