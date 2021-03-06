//
//  FirstViewController.swift
//  Timetable
//
//  Created by Cubic on 2015/02/09.
//  Copyright (c) 2015年 Cubic. All rights reserved.
//

import UIKit
import Realm

let TODAY = NSDate()
let CLASSSYMBOLS = [ "1M", "1E", "1C", "1A", "2M", "2E", "2C", "2A", "3M", "3E", "3C", "3A", "4M", "4ED", "4EJ", "4C", "4A", "5M", "5ED", "5EJ", "5C", "5A", "1ME", "1AC", "2ME", "2AC", "-" ]
let SYMBOLTODEPARTMENT = [ "M": "機械工学科", "E": "電気情報工学科", "C": "都市システム工学科", "A": "建築学科",  "ME": "機械・電子システム工学専攻", "AC": "建築・都市システム工学専攻" ]
let TIMESPANTOPERIODS = [
	"09:00:00+09:00": ["10:30:00+09:00" : [1], "12:10:00+09:00" : [1, 2]],
	"10:40:00+09:00": ["12:10:00+09:00" : [2]],
	"13:00:00+09:00": ["14:30:00+09:00" : [3], "16:10:00+09:00" : [3, 4]],
	"14:40:00+09:00": ["16:10:00+09:00" : [4]]
]

class FirstViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
	@IBOutlet weak var toolBar: UIToolbar!
	@IBOutlet weak var timetableView: PersistScrollView!
	@IBOutlet weak var pickerResignButton: UIButton!
	@IBOutlet weak var classTextField: UITextField!
	var picker = UIPickerView()
	var realm : RLMRealm?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		realmSetSchema()
		
		realm = RLMRealm.defaultRealm()
		
		self.realm!.transactionWithBlock() {
			self.realm!.addOrUpdateObject(Subject(title: "", location: "", deduction: 0))
		}

		toolBar.items?.insert(UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: "editButtonPushed:"), atIndex: 0)
		
		self.timetableView.pageGenerator = {
			let date = TODAY.succ(.CalendarUnitDay, value: $0)!
			
			var sessions = [Session?]()

			for i in 1..<20 {
				if let s = Session.find(date.weekday(), period: i) {
					sessions.append(s)
				} else {
					break
				}
			}
			
//			for s in Session.objectsWhere("day = \(date.weekday())").sortedResultsUsingProperty("period", ascending: true)  {
//				sessions.append(s as? Session)
//			}
			
//			if !sessions.isEmpty {
//				for i in 1 ..< sessions.last!!.period {
//					if sessions[i-1]!.period != i {
//						let subject = Subject(title: "", location: "", deduction: Float(0))
//						sessions.insert(Session(day: date.weekday(), period: i, subject: subject), atIndex: i-1)
//					}
//				}
//			}
			
			var ret = DateTableView.instance(date, sessions: sessions)
			ret.setEditing(self.editing, animated: false)
			return ret
		}
		
		self.timetableView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: "longPressed:") => {
			$0.minimumPressDuration = 1.0;
		})
		
		classTextField.text = UserInfo.origin().classInfo
		
		picker.delegate = self
		picker.dataSource = self
		picker.showsSelectionIndicator = true
		classTextField.inputView = picker
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}
	
	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	override func viewDidDisappear(animated: Bool) {
		super.viewDidDisappear(animated)
	}
	
	var isObserving = false
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		if(!isObserving) {
			let notification = NSNotificationCenter.defaultCenter()
			notification.addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
			notification.addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
			isObserving = true
		}
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		if(isObserving) {
			let notification = NSNotificationCenter.defaultCenter()
			notification.removeObserver(self)
			notification.removeObserver(self, name: UIKeyboardWillShowNotification, object: nil)
			notification.removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
			isObserving = false
		}
	}
	
	func URLbyDate(year : Int, month : Int) -> NSURL? {
		let urlPreffix = "http://www.akashi.ac.jp/data/timetable/timetable"
		
		switch(month) {
		case 1...3:
			return NSURL(string: urlPreffix + "\(year-1)10.xml")
		case 4:
			if let url = NSURL(string: urlPreffix + "\(year)04.xml") {
				return url
			}
			return NSURL(string: urlPreffix + "\(year-1)10.xml")
		case 5...9:
			return NSURL(string: urlPreffix + "\(year)04.xml")
		case 10:
			if let url = NSURL(string: urlPreffix + "\(year)10.xml") {
				return url
			}
			return NSURL(string: urlPreffix + "\(year)04.xml")
		case 11...12:
			return NSURL(string: urlPreffix + "\(year)10.xml")
		default:
			return nil
		}
	}
	
	func loadFromWeb(url : NSURL, myGrade : Int, myDepartment : String, myCourse : String?) {
		let xml = SWXMLHash.parse(NSData(contentsOfURL: url)!)

		for lecture in xml["Timetable_xml"]["Timetable"]["Lectures"]["Lecture"].all {
			let grade = lecture["Grade"].element!.text!.toInt()
			let department = lecture["Department"].element!.text!
			let course = lecture["Course"].element?.text
			
			if grade == myGrade && department == myDepartment && course == myCourse {
				for period in lecture["Periods"]["Period"].all {
					let wday = period["Wday"].element!.text!.toInt()! + 1
					let startTime = period["StartTime"].element!.text!
					var endTime = period["EndTime"].element!.text!
					
					if endTime == "15:25:00+09:00" {
						endTime = "16:10:00+09:00"
					}
					
					let name = lecture["Name"].element?.text
					let location = lecture["Location"].element?.text
					
					realm!.transactionWithBlock() {
						for p in TIMESPANTOPERIODS[startTime]![endTime]! {
							var deduction = Float(0)
							if let s = Subject.find(name!) {
								deduction = s.deduction
							}
						
							var subject = Subject(title: name!, location: location ?? "", deduction: deduction)
							var session = Session(day: wday, period: p, subject: subject)
						
							self.realm!.addOrUpdateObject(subject)
							self.realm!.addOrUpdateObject(session)
						}
					}
				}
			}
		}
	}
	
	func longPressed(sender: UILongPressGestureRecognizer) {
		if sender.state != UIGestureRecognizerState.Began {
			return
		}
		
		let currentTableView = self.timetableView.currentView as? DateTableView
		let wday = currentTableView!.date!.weekday()
		let point = sender.locationInView(currentTableView)
		if let period = currentTableView!.indexPathForRowAtPoint(point)?.row {
			var session = Session.find(wday, period: period + 1)!
			var alert = UIAlertController(title: session.subject.title, message: nil, preferredStyle: .ActionSheet)

			for tuple in [("欠席(-1.0)", Float(1.0)), ("遅刻(-0.5)", Float(0.5))] {
				alert.addAction(UIAlertAction(title: tuple.0, style: UIAlertActionStyle.Default, handler: { action in
					self.realm?.transactionWithBlock() {
						session.subject.deduction -= tuple.1
					}
					currentTableView!.reloadData()
				}))
			}

			alert.addAction(UIAlertAction(title: "キャンセル", style: .Cancel, handler: nil))
			
			if let cell = currentTableView!.cellForRowAtIndexPath(NSIndexPath(forRow: period, inSection: 0)) {
				alert.popoverPresentationController?.sourceView = cell
				alert.popoverPresentationController?.sourceRect = cell.bounds
			}
			
			self.presentViewController(alert, animated: true, completion: nil)
		}
	}
	
	func editButtonPushed(sender: UIButton) {
		toolBar.items?.removeAtIndex(0)
		toolBar.items?.insert(UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "addButtonPushed:"), atIndex: 0)
		toolBar.items?.insert(UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: self, action: nil), atIndex: 0)
		toolBar.items?.insert(UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "doneButtonPushed:"), atIndex: 0)
		setEditing(true, animated: true)
	}
	
	func doneButtonPushed(sender: UIButton) {
		toolBar.items?.removeRange(0...2)
		toolBar.items?.insert(UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: "editButtonPushed:"), atIndex: 0)
		setEditing(false, animated: true)
	}
	
	func addButtonPushed(sender: UIButton) {
		var view = (self.timetableView.currentView as! DateTableView)
		let period = view.numberOfRowsInSection(0)
		let newIndexPath = NSIndexPath(forRow: period, inSection: 0)
		if Subject.find("") == nil {
			self.realm!.transactionWithBlock() {
				self.realm!.addOrUpdateObject(Subject(title: "", location: "", deduction: Float(0.0)))
			}
		}
		let session = Session(day: view.date!.weekday(), period: period + 1, subject: Subject.find("")!)
		
		self.realm!.transactionWithBlock() {
			self.realm!.addOrUpdateObject(session)
		}
		
		view.sessions.append(session)
		view.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: UITableViewRowAnimation.Left)
	}
	
	override func setEditing(editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		
		for subview in self.timetableView.subviews {
			subview.setEditing(editing, animated: animated)
		}
	}
	
	// both keyboard and picker call this method
	func keyboardWillShow(notification: NSNotification?) {
		if let textField = self.view.getFirstResponder() {
			if textField.inputView is UIPickerView {
				pickerResignButton?.hidden = false
				return
			}
			
			let textFieldY = textField.absPoint().y + textField.frame.height
			let keyboardY = (notification?.userInfo?[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue().minY
			let offsetY = textFieldY - min(keyboardY, textFieldY)
		
			(self.timetableView.currentView as! DateTableView).setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)
		}
		
		self.timetableView.scrollEnabled = false
	}
	
	// both keyboard and picker call this method
	func keyboardWillHide(notification: NSNotification?) {
		if self.view.getFirstResponder()?.inputView is UIPickerView {
			return
		}
		
		let currentTableView = self.timetableView.currentView as! DateTableView
		if currentTableView.numberOfRowsInSection(0) == 0 {
			return
		}

		for i in 0 ..< currentTableView.numberOfRowsInSection(0) {
			if let cell = currentTableView.cellForRowAtIndexPath(NSIndexPath(forRow: i, inSection: 0)) as? SessionCell {
				realm?.transactionWithBlock() {
					let subject = Subject(title: cell.titleTextField.text, location: cell.locationTextField.text, deduction: cell.deductionTextField.text.floatValue)
					let wday = (self.timetableView.currentView as! DateTableView).date?.weekday()
					let session = Session(day: wday!, period: i+1, subject: subject)
					
					self.realm?.addOrUpdateObject(subject)
					self.realm?.addOrUpdateObject(session)
				}
			}
		}
		
		(self.timetableView.currentView as! DateTableView).setContentOffset(CGPoint(x: 0, y: 0), animated: true)
		
		self.timetableView.scrollEnabled = true
	}
	
	@IBAction func hideButtonPushed(sender: UIButton) {
		pickerResignButton?.hidden = true
		var cls = pickerView(picker, titleForRow: picker.selectedRowInComponent(0), forComponent: 0)
		
		if cls != "-" {
			let grade = String(cls[cls.startIndex]).toInt()!
			var department = String(cls[advance(cls.startIndex, 1)])
			var course : String? = nil

			if count(cls) == 3 {
				let i = advance(cls.startIndex, 2)
				if cls[i] == "D" {
					course = "電気電子工学コース"
				} else if cls[i] == "J" {
					course = "情報工学コース"
				} else {
					department.append(cls[i])
				}
			}
			
			var url : NSURL
			if NSData(contentsOfURL: URLbyDate(TODAY.year(), month: TODAY.month())!) != nil {
				url = URLbyDate(TODAY.year(), month: TODAY.month())!
			} else {
				url = URLbyDate(TODAY.succ(.CalendarUnitMonth, value: -1)!.year(), month: TODAY.succ(.CalendarUnitMonth, value: -1)!.month())!
			}
			
			let str = url.absoluteString!
			let year = str.substringWithRange(Range<String.Index>(start: advance(str.endIndex, -10), end: advance(str.endIndex, -6)))
			let month = str.substringWithRange(Range<String.Index>(start: advance(str.endIndex, -6), end: advance(str.endIndex, -4)))
			let alert = UIAlertController(title: "最新のシラバスをダウンロードします。", message: "最新の時間割は\(year)年\(month)月のものです。ダウンロード完了後に自動で時間割が書き換わります。", preferredStyle: .Alert)
			
			alert.addAction(UIAlertAction(title: "確認", style: .Default, handler: { action in
				self.realm?.transactionWithBlock() {
					self.realm?.deleteObjects(Session.allObjects())
					var info = UserInfo.origin()
					info.classInfo = cls
					self.realm?.addOrUpdateObject(info)
				}
				
				self.classTextField.text = cls
				self.loadFromWeb(url, myGrade: grade, myDepartment: SYMBOLTODEPARTMENT[department]!, myCourse: course)
				self.timetableView.reloadContents()
			}))
			
			alert.addAction(UIAlertAction(title: "キャンセル", style: .Cancel, handler: nil))
			presentViewController(alert, animated: true) {
				self.classTextField.resignFirstResponder()
			}
		} else {
			self.realm?.transactionWithBlock() {
				var info = UserInfo.origin()
				info.classInfo = cls
				self.realm?.addOrUpdateObject(info)
				self.realm?.deleteObjects(Session.allObjects())
			}
			
			self.classTextField.text = cls
			self.view.getFirstResponder()?.resignFirstResponder()
		}
	}

	func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
		return 1
	}
	
	func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return CLASSSYMBOLS.count
	}

	func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
		return CLASSSYMBOLS[row]
	}
	
	func realmSetSchema() {
		RLMRealm.setSchemaVersion(7, forRealmAtPath: RLMRealm.defaultRealmPath(), withMigrationBlock: { migration, oldSchemaVersion in
			migration.enumerateObjects(Session.className()) { oldObject, newObject in
				if oldSchemaVersion < 6 {
					self.realm!.transactionWithBlock() {
						self.realm!.addOrUpdateObject(Subject(title: "", location: "", deduction: 0))
					}
				}
			}
			
			migration.enumerateObjects(Subject.className()) { oldObject, newObject in
				if oldSchemaVersion < 7 {
					newObject["title"] = oldObject["title"]
					newObject["location"] = oldObject["location"]
					newObject["deduction"] = oldObject["deduction"]
				}
			}
		})
	}
}
