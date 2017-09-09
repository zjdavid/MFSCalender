//
//  ClassTimetableViewController.swift
//  MFSCalendar
//
//  Created by David Dai on 2017/8/7.
//  Copyright © 2017年 David. All rights reserved.
//

import UIKit
import XLPagerTabStrip

class timeTableParentViewController: TwitterPagerTabStripViewController {
    override public func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] {
        var arrayToReturn = [UIViewController]()
        for alphabet in "ABCDEF".characters {
            let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier :"timeTableViewController") as! ADay
            
            viewController.daySelected = String(alphabet)
            
            arrayToReturn.append(viewController)
        }
        return arrayToReturn
    }
    
}

