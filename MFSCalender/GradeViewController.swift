//
//  GradeViewController.swift
//  MFSCalendar
//
//  Created by David Dai on 2017/7/17.
//  Copyright © 2017年 David. All rights reserved.
//

import UIKit
import XLPagerTabStrip
import UICircularProgressRing
import SwiftyJSON
import SwiftMessages
import DGElasticPullToRefresh
import SVProgressHUD
import Alamofire
import Charts
import SnapKit
import Crashlytics

enum Quarters {
    case first
    case second
    case third
    case forth
}

class gradeViewController: UITableViewController {
    var classObject = [String: Any]()
    var gradeList = [[String: Any]]()
    var groupedGradeList = [String: [[String: Any]]]()
    var groupedGradeKeys: [String] {
        return Array(groupedGradeList.keys)
    }
    
    
    let dateFormatter = DateFormatter()
    var quarterSelected: Int = 1
    

    var cumGrade: Float = 0 {
        didSet {
            DispatchQueue.main.async {
                self.cumGradeProgressRing.startProgress(to: CGFloat(self.cumGrade), duration: 1.0)
            }
        }
    }
    
    @IBOutlet var cumGradeProgressRing: UICircularProgressRing!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cumGradeProgressRing.font = UIFont.boldSystemFont(ofSize: 32)
        setQuarterBasedOnCurrentQuarter()
    }

    override func viewWillAppear(_ animated: Bool) {
        DispatchQueue.global().async {
            self.refreshView()
        }

        let loadingview = DGElasticPullToRefreshLoadingViewCircle()
        loadingview.tintColor = UIColor.white
        tableView.dg_addPullToRefreshWithActionHandler({ [weak self] () -> Void in
            self?.refreshView()
            self?.tableView.dg_stopLoading()
        }, loadingView: loadingview)
        tableView.dg_setPullToRefreshFillColor(UIColor(hexString: 0xFF7E79))
        tableView.dg_setPullToRefreshBackgroundColor(tableView.backgroundColor!)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        self.animate()
        Answers.logContentView(withName: "Grade", contentType: "Grade", contentId: "2", customAttributes: nil)
    }
    
    func setQuarterBasedOnCurrentQuarter() {
        quarterSelected = Preferences().currentQuarter
    }
    
    @objc func changeQuarter(sender: UIButton) {
        switch quarterSelected {
        case 1:
            quarterSelected = 2
            sender.setTitle("2nd Quarter", for: .normal)
        case 2:
            quarterSelected = 3
            sender.setTitle("3rd Quarter", for: .normal)
        case 3:
            quarterSelected = 4
            sender.setTitle("4th Quarter", for: .normal)
        case 4:
            quarterSelected = 1
            sender.setTitle("1st Quarter", for: .normal)
        default:
            quarterSelected = 1
            sender.setTitle("1st Quarter", for: .normal)
        }
        
        refreshView()
    }

    func refreshView() {
        DispatchQueue.main.async {
            self.navigationController?.showProgress()
            self.navigationController?.setIndeterminate(true)
            SVProgressHUD.show()
        }
        
        classObject = ClassView().getTheClassToPresent() ?? [String: Any]()
        
        let group = DispatchGroup()
        
        DispatchQueue.global().async(group: group, execute: {
            self.getcumGrade()
        })
        
        DispatchQueue.global().async(group: group, execute: {
            self.getGradeDetail()
        })
        
        group.wait()
        
        DispatchQueue.main.async {
            self.navigationController?.cancelProgress()
            SVProgressHUD.dismiss()
            self.tableView.reloadData()
//            self.setupSectionGradeChart()
        }
        
    }
    
//    func setupSectionGradeChart() {
//        sectionGradeChart.drawBarShadowEnabled = false
//        sectionGradeChart.chartDescription?.text = ""
//        sectionGradeChart.rightAxis.enabled = false
//
//        let yAxisFormatter = NumberFormatter()
//        yAxisFormatter.minimumFractionDigits = 0
//        yAxisFormatter.maximumFractionDigits = 1
//        yAxisFormatter.positiveSuffix = " %"
//
//        let yAxis = sectionGradeChart.xAxis
//
//        yAxis.labelFont = UIFont.systemFont(ofSize: 10)
//        yAxis.labelCount = 6
//        yAxis.valueFormatter = DefaultAxisValueFormatter(formatter: yAxisFormatter)
//        yAxis.axisMinimum = 0
//
//        let legend = sectionGradeChart.legend
//        legend.horizontalAlignment = .left
//        legend.verticalAlignment = .bottom
//        legend.orientation = .horizontal
//        legend.xEntrySpace = 4.0
//
//        guard !gradeList.isEmpty else { return }
//
//
//
//        for assignmentType in groupedGradeKeys {
//
//            guard let gradeListOfThisType = groupedGradeList[assignmentType] else { continue }
//            var yValues = [BarChartDataEntry]()
//            for grade in gradeListOfThisType {
//                guard let gradePercent = grade["AssignmentPercentage"] as? Double else {
//                    continue
//                }
//                let dataEntry = BarChartDataEntry(x: Double(grade["index"] as! Int), y: gradePercent)
//                yValues.append(dataEntry)
//            }
//
//            let dataSet = BarChartDataSet(values: yValues, label: assignmentType)
//            dataSet.setColor(HomeworkView().colorForTheType(type: assignmentType), alpha: 0.7)
////
////            if let data = cell.chartView.data {
////                data.addDataSet(dataSet)
////            } else {
////                let data = BarChartData(dataSet: dataSet)
////                //data.setValueFont(UIFont.systemFont(ofSize: 10))
////
////                cell.chartView.data = data
////            }
//        }
////
////        cell.chartView.data?.notifyDataChanged()
////        cell.chartView.notifyDataSetChanged()
////
////        cell.chartView.noDataText = "No grade data is found."
////
////        return cell
//    }
    
    func animate() {
        cumGradeProgressRing.startProgress(to: CGFloat(self.cumGrade), duration: 1.0)
        
//        if let chartCell = self.tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? gradeBarChartCell {
//            print(chartCell.chartView.data)
//        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        tableView.dg_removePullToRefresh()
    }
    
    func getGradeDetail() {
        guard loginAuthentication().success else { return }
        let userID = loginAuthentication().userId
        guard let sectionIDInt = ClassView().getLeadSectionID(classDict: classObject) else { return }
        var sectionID = String(describing: sectionIDInt)
        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) {
            sectionID = ClassView().getLeadSectionIDFromSectionInfo(sectionID: sectionID)
        }
        
        group.wait()
        
        let markingPeriodID = String(school.getMarkingPeriodID(quarter: quarterSelected))
        
        let url = Preferences().baseURL + "/api/datadirect/GradeBookPerformanceAssignmentStudentList/?sectionId=\(sectionID)&markingPeriodId=\(markingPeriodID)&studentUserId=\(userID)"
        
        let semaphore = DispatchSemaphore(value: 0)
        
        Alamofire.request(url).response(queue: DispatchQueue.global(), completionHandler: { result in
            if result.error == nil {
                do {
                    let json = try JSONSerialization.jsonObject(with: result.data!, options: .allowFragments) as? [[String: Any]] ?? [[String: Any]]()
                    
                    self.gradeList = json
                } catch {
                    presentErrorMessage(presentMessage: error.localizedDescription, layout: .statusLine)
                }
            }
            
            semaphore.signal()
        })
        
        semaphore.wait()
        classifyGradeData()
    }
    
    func classifyGradeData() {
        groupedGradeList = [:]
        guard gradeList.count > 0 else { return }
        
        for (index, gradeObject) in gradeList.enumerated() {
            var gradeWithDate = gradeObject
            if let dateDueString = gradeObject["DateDue"] as? String {
                dateFormatter.dateFormat = "M/dd/yyyy h:mm a"
                if let dateDue = dateFormatter.date(from: dateDueString) {
                    gradeWithDate["DateDue"] = dateDue
                }
            }
            
            gradeList[index] = gradeWithDate
        }
        
        gradeList.sort(by: {
            ($0["DateDue"] as? Date ?? Date()).compare($1["DateDue"] as? Date ?? Date()) == .orderedAscending
        })
        
        for (index, grade) in gradeList.enumerated() {
            var gradeWithIndex = grade
            gradeWithIndex["index"] = index
            gradeList[index] = gradeWithIndex
        }
        
        let groupedData = gradeList.group(by: { $0["AssignmentType"] as? String ?? "" })
        print(groupedData)
        groupedGradeList = groupedData
    }

    func getcumGrade() {
        let className = classObject["className"] as? String ?? ""
        let durationId = school.getDurationNumber(quarter: quarterSelected)
        NetworkOperations().getCourseFromMyMFS(durationId: String(durationId), completion: { (courseData) in
            if let presentingClass = courseData.filter({ $0["sectionidentifier"] as? String ?? "" == className }).first {
                self.cumGrade = Float(presentingClass["cumgrade"] as? String ?? "") ?? 0.0
            }
        })
    }
}

extension gradeViewController {
//    UITableviewDelegate and UITableviewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1 + groupedGradeKeys.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            if !groupedGradeKeys.indices.contains(section - 1) {
                return 0
            }
            return groupedGradeList[groupedGradeKeys[section - 1]]?.count ?? 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                let cell = self.tableView.dequeueReusableCell(withIdentifier: "chartsView") as! gradeBarChartCell
                
                cell.chartView.clear()
                cell.chartView.delegate = self
                cell.chartView.drawBarShadowEnabled = false
                cell.chartView.maxVisibleCount = 10
                //cell.chartView.xAxis.labelPosition = .bottom
                cell.chartView.chartDescription?.text = ""
                cell.chartView.rightAxis.enabled = false
                cell.chartView.xAxis.enabled = false
                cell.chartView.isUserInteractionEnabled = true
                
                cell.chartView.drawValueAboveBarEnabled = true
                
                let yAxisFormatter = NumberFormatter()
                yAxisFormatter.minimumFractionDigits = 0
                yAxisFormatter.maximumFractionDigits = 1
                yAxisFormatter.positiveSuffix = " %"
                
                let yAxis = cell.chartView.leftAxis
                yAxis.labelFont = UIFont.systemFont(ofSize: 12)
                yAxis.labelCount = 6
                yAxis.valueFormatter = DefaultAxisValueFormatter(formatter: yAxisFormatter)
                yAxis.labelPosition = .outsideChart
                yAxis.spaceTop = 0.15
                yAxis.axisMinimum = 0
                
                let legend = cell.chartView.legend
                legend.horizontalAlignment = .left
                legend.verticalAlignment = .bottom
                legend.orientation = .horizontal
                legend.font = UIFont.systemFont(ofSize: 12)
                legend.xEntrySpace = 4.0
                
                guard !gradeList.isEmpty else { break }
                
                if cell.chartView.data?.dataSetCount != groupedGradeKeys.count {
                    for assignmentType in groupedGradeKeys {
                        guard let gradeListOfThisType = groupedGradeList[assignmentType] else { continue }
                        var yValues = [BarChartDataEntry]()
                        for grade in gradeListOfThisType {
                            guard let gradePercent = grade["AssignmentPercentage"] as? Double else {
                                continue
                            }
                            let dataEntry = BarChartDataEntry(x: Double(grade["index"] as! Int), y: gradePercent)
                            yValues.append(dataEntry)
                        }
                        
                        let dataSet = BarChartDataSet(values: yValues, label: assignmentType)
                        dataSet.setColor(HomeworkView().colorForTheType(type: assignmentType), alpha: 0.7)
                        dataSet.valueFont = UIFont.systemFont(ofSize: 12)
                        
                        if let data = cell.chartView.data {
                            data.addDataSet(dataSet)
                        } else {
                            let data = BarChartData(dataSet: dataSet)
                            //data.setValueFont(UIFont.systemFont(ofSize: 10))
                            
                            cell.chartView.data = data
                        }
                    }
                    
                    cell.chartView.data?.notifyDataChanged()
                    cell.chartView.notifyDataSetChanged()
                }
                
                cell.chartView.noDataText = "No grade data is found."
                
                return cell
            default:
                break
            }
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "gradeDetail", for: indexPath) as! gradeDetailCell
            
            // The section begins at 1, while the array index begins at 0.
            let section = indexPath.section - 1
            guard groupedGradeKeys.indices.contains(section) else { break }
            guard let gradeInSection = groupedGradeList[groupedGradeKeys[section]] else { break }
            
            let row = indexPath.row
            guard gradeInSection.indices.contains(indexPath.row) else { break }
            let gradeObject = gradeInSection[row]
            
            print(gradeObject)
            
            let additionalInfo = 
            
            let name = gradeObject["AssignmentShortDescription"] as? String ?? ""
            cell.name.attributedText = name.convertToHtml()
            
            cell.date.text = ""
            if let dateDue = gradeObject["DateDue"] as? Date {
                dateFormatter.dateFormat = "MMM d"
                
                let dateToDisplay = dateFormatter.string(from: dateDue)
                cell.date.text = dateToDisplay
            }
            
            cell.grade.text = ""
            if let points = gradeObject["Points"] as? String, let maxPoints = gradeObject["MaxPoints"] as? Int {
                cell.grade.text = points + "/" + String(describing: maxPoints)
            }
            
            return cell
        }

        return UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 280
        } else {
            return UITableView.automaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 49
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableCell(withIdentifier: "tableHeader") as! homeworkTableHeader
        
        if section == 0 {
            view.titleLabel.text = "Overview"
            let quarterButton = UIButton()
            
            quarterButton.setTitle("Quarter " + String(quarterSelected), for: .normal)
            
            view.addSubview(quarterButton)
            quarterButton.titleLabel?.font = UIFont.systemFont(ofSize: 15)
            quarterButton.snp.makeConstraints({ make in
                make.trailing.equalTo(view.snp.trailingMargin).offset(-10)
                make.height.equalTo(view.titleLabel.snp.height)
                make.centerY.equalTo(view.snp.centerY)
            })
                
             quarterButton.addTarget(self, action: #selector(changeQuarter(sender:)), for: .touchUpInside)
        } else {
            view.titleLabel.text = groupedGradeKeys[section - 1]
        }
        
        return view
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
}

extension gradeViewController: ChartViewDelegate {
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        chartView.highlightValue(nil)
        let masterIndex = Int(entry.x)
        guard gradeList.indices.contains(masterIndex) else { return }
        let gradeObject = gradeList[masterIndex]
        guard let assignmentType = gradeObject["AssignmentType"] as? String else { return }
        let sectionIndex = Int(groupedGradeKeys.firstIndex(of: assignmentType) ?? 0) + 1
        
        guard let gradeInSection = groupedGradeList[assignmentType] else { return }
        guard let rowArrayIndex = gradeInSection.firstIndex(where: { $0["index"] as? Int == masterIndex }) else { return }
        let rowIndex = Int(rowArrayIndex)
        
        let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
        if tableView.cellForRow(at: indexPath) != nil {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
        }
    }
}

extension gradeViewController: IndicatorInfoProvider {
    func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
        return IndicatorInfo(title: "GRADE")
    }
}

class gradeDetailCell: UITableViewCell {
    @IBOutlet var date: UILabel!
    @IBOutlet var name: UILabel!
    @IBOutlet var grade: UILabel!
}

class gradeBarChartCell: UITableViewCell {
    @IBOutlet var chartView: BarChartView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        chartView.animate(yAxisDuration: 3.0)
    }
}
