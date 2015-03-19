//
//  EditableSessionCell.swift
//  Timetable
//
//  Created by Cubic on 2015/03/19.
//  Copyright (c) 2015年 Cubic. All rights reserved.
//

import Foundation
import UIKit

class EditableSessionCell : UITableViewCell {
	@IBOutlet weak var deleteButton: UIButton!
	@IBOutlet weak var titleTextField: UITextField!
	@IBOutlet weak var deductionTextField: UITextField!
	@IBOutlet weak var locationTextField: UITextField!
	@IBOutlet weak var periodLabelView: UILabel!
	
	var session : Session? {
		didSet {
			self.periodLabelView.text = self.session.map { $0.period.description + "限" }
			self.locationTextField.text = self.session?.subject.location
			self.titleTextField.text = self.session?.subject.title
			if let d = self.session?.subject.deduction {
				self.deductionTextField.text = d.description
			} else {
				self.deductionTextField.text = ""
			}
		}
	}
	
	class func instance(session : Session?) -> EditableSessionCell {
		return UINib(nibName: "EditableSessionCell", bundle: nil).instantiateWithOwner(self, options: nil).first as EditableSessionCell => {
			$0.session = session
		}
	}
	
}