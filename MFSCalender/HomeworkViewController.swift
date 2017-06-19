//
//  HomeworkViewController.swift
//  MFSCalendar
//
//  Created by 戴元平 on 2017/6/14.
//  Copyright © 2017年 David. All rights reserved.
//

import UIKit
import SwiftMessages
import SwiftyJSON
import HTMLLabel
import HTMLString
import M13Checkbox
import SwiftDate

class homeworkViewController: UITableViewController {
    
    
    
    
    @IBOutlet weak var homeworkTable: UITableView!
    
    var listHomework = [String: Array<NSDictionary>]()
    var sections: [String] {
        return Array(self.listHomework.keys).sorted()
    }
    
    let formatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        homeworkTable.rowHeight = UITableViewAutomaticDimension
        homeworkTable.estimatedRowHeight = 80
    }
    
    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.global().async {
            self.getHomework()
        }
    }
    
    func errorMessage(presentMessage: String) {
        let view = MessageView.viewFromNib(layout: .CardView)
        view.configureTheme(.error)
        var icon: String? = nil
        if presentMessage == "The username/password is incorrect. Please check your spelling." {
            icon = "🤔"
        } else {
            icon = "😱"
        }
        view.configureContent(title: "Error!", body: presentMessage, iconText: icon!)
        view.button?.isHidden = true
        let config = SwiftMessages.Config()
        SwiftMessages.show(config: config, view: view)
    }
    
    func getHomework() {
        guard let username = userDefaults?.string(forKey: "username") else { return }
        var request = URLRequest(url: URL(string:"https://dwei.org/assignmentlist/")!)
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
        let session = URLSession.init(configuration: config)
        
        if username != "testaccount" {
            let (success, token) = loginAuthentication()
            if success {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US")
                formatter.dateFormat = "M/d/yyyy"
                let today = formatter.string(from: Date()).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                let url = "https://mfriends.myschoolapp.com/api/DataDirect/AssignmentCenterAssignments/?format=json&filter=2&dateStart=\(today)&dateEnd=\(today)&persona=2"
                request.url = URL(string:url)
                let cookieProps: [HTTPCookiePropertyKey : Any] = [
                    HTTPCookiePropertyKey.domain: "mfriends.myschoolapp.com",
                    HTTPCookiePropertyKey.path: "/",
                    HTTPCookiePropertyKey.name: "token",
                    HTTPCookiePropertyKey.value: token
                ]
                
                if let cookie = HTTPCookie(properties: cookieProps) {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                
                let cookieProps2: [HTTPCookiePropertyKey : Any] = [
                    HTTPCookiePropertyKey.domain: "mfriends.myschoolapp.com",
                    HTTPCookiePropertyKey.path: "/",
                    HTTPCookiePropertyKey.name: "bridge",
                    HTTPCookiePropertyKey.value: "action=create&src=webapp&xdb=true"
                ]
                
                if let cookie = HTTPCookie(properties: cookieProps2) {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
            }
        }
        var originalData = [NSDictionary]()
        let semaphore = DispatchSemaphore.init(value: 0)
        let task: URLSessionDataTask = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if error == nil {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? Array<NSDictionary> {
                        print(json)
                        originalData = json
                    }
                    
                } catch {
                    NSLog("Data parsing failed")
                    DispatchQueue.main.async {
                        let presentMessage = "The server is not returning the right data. Please contact David."
                        self.errorMessage(presentMessage: presentMessage)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    let presentMessage = (error?.localizedDescription)! + " Please check your internet connection."
                    self.errorMessage(presentMessage: presentMessage)
                }
            }
            semaphore.signal()
        })
        
        task.resume()
        semaphore.wait()
        manageDate(originalData: originalData)
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func manageDate(originalData: Array<NSDictionary>) {
        var managedHomework = [String: Array<NSDictionary>]()
//        Format: [DateDue(YearMonthDay): Array<HomeworkBelongToThatSection>]
        for homework in originalData {
            guard let dueDateData = homework["date_due"] as? String else { return }
            formatter.dateFormat = "M/d/yyyy hh:mm a"
            formatter.locale = Locale(identifier: "en_US")
            let dueDate = formatter.date(from: dueDateData)
            formatter.locale = Locale.current
//            Let it crash
            formatter.dateFormat = "yyyyMMdd"
            if dueDate != nil {
                let dueDateMDString = formatter.string(from: dueDate!)
                var homeworkArray = managedHomework[dueDateMDString]
                if homeworkArray == nil {
                    homeworkArray = []
                }
                homeworkArray?.append(homework)
                managedHomework[dueDateMDString] = homeworkArray
            }
        }
        
        self.listHomework = managedHomework
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let homeworkInSection = self.listHomework[sections[section]] else { return 0 }
        return homeworkInSection.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        print(sections)
        return self.listHomework.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        TODO: 加入这周内容
        let dueDateMDString = sections[section]
        formatter.dateFormat = "yyyyMMdd"
        guard let dueDate = formatter.date(from: dueDateMDString) else { return "Unknown" }
        if dueDate.isToday {
            return "Today"
        } else if dueDate.isTomorrow {
            return "Tomorrow"
        } else {
            return dueDate.string(format: .custom("EEEE, MMM d, yyyy"))
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "homeworkViewCell", for: indexPath) as! homeworkViewCell
        
        let homeworkInSection = self.listHomework[sections[indexPath.section]]
        guard let homework = homeworkInSection?[indexPath.row] else { return cell }
        if let assignmentId = homework["assignment_id"] as? Int {
            cell.assignmentId = String(describing:assignmentId)
        }
        
        if let sectionId = homework["section_id"] as? Int {
            cell.sectionId = String(describing:sectionId)
        }
        var description = homework["short_description"] as? String
        description = description?.removingHTMLEntities
        cell.title.text = description ?? ""
        cell.title.sizeToFit()
        
        cell.homeworkClass.text = homework["groupname"] as? String
        
        let homeworkType = homework["assignment_type"] as? String
        cell.homeworkType.text = homeworkType
        
        if homeworkType != nil {
            switch homeworkType! {
            case "Homework":
                cell.tagView.backgroundColor = UIColor(hexString: 0xF44336)
            case "Quiz":
                cell.tagView.backgroundColor = UIColor(hexString: 0x2196F3)
            case "Test":
                cell.tagView.backgroundColor = UIColor(hexString: 0x3F51B5)
            case "Project":
                cell.tagView.backgroundColor = UIColor(hexString: 0xFF9800)
            case "Classwork":
                cell.tagView.backgroundColor = UIColor(hexString: 0x795548)
            default:
                cell.tagView.backgroundColor = UIColor(hexString: 0x607D8B)
            }
        }
        
        if let status = homework["assignment_status"] as? Int {
            switch status {
            case -1:
                cell.checkMark.setCheckState(.unchecked, animated: false)
            case 1:
                cell.checkMark.setCheckState(.checked, animated: false)
            default:
                cell.checkMark.setCheckState(.unchecked, animated: false)
            }
        }
        
        cell.checkMark.tintColor = cell.tagView.backgroundColor
        return cell
    }
}

class homeworkViewCell: UITableViewCell {
    @IBOutlet weak var title: HTMLLabel!
    @IBOutlet weak var checkMark: M13Checkbox!
    @IBOutlet weak var homeworkType: UILabel!
    @IBOutlet weak var homeworkClass: UILabel!
    @IBOutlet weak var tagView: UIView!
    
    var assignmentId: String?
    var sectionId: String?
    
    override func awakeFromNib() {
        checkMark.stateChangeAnimation = .bounce(.fill)
        checkMark.boxLineWidth = 3
        checkMark.addTarget(self, action: #selector(checkDidChange), for: UIControlEvents.valueChanged)
    }
    
    func checkDidChange(checkMark: M13Checkbox) {
        guard (assignmentId != nil) else { return }
        guard (sectionId != nil) else { return }
        
        var assignmentStatus: String? = nil
        
        switch checkMark.checkState {
        case .checked:
            assignmentStatus = "1"
        case .unchecked:
            assignmentStatus = "-1"
        default:
            NSLog("Something strange happened.")
        }
        
        var url: String? = nil
        
        if userDefaults?.string(forKey: "username") == "testaccount" {
            url = "https://dwei.org/updateAssignmentStatus/" + assignmentId! + "/" + sectionId! + "/" + assignmentStatus!
        }
        
        let request = URLRequest(url: URL(string: url!)!)
        let session = URLSession.shared
        
        let task: URLSessionDataTask = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if error == nil {
                
            } else {
                switch checkMark.checkState {
                case .checked:
                    checkMark.setCheckState(.unchecked, animated: false)
                case .unchecked:
                    checkMark.setCheckState(.checked, animated: false)
                default:
                    break
                }
                let presentMessage = error!.localizedDescription + "Please check your internet connection"
                let view = MessageView.viewFromNib(layout: .CardView)
                view.configureTheme(.error)
                view.configureContent(title: "Error!", body: presentMessage)
                view.button?.isHidden = true
                let config = SwiftMessages.Config()
                SwiftMessages.show(config: config, view: view)
            }
        })
        
        task.resume()
    }
}
