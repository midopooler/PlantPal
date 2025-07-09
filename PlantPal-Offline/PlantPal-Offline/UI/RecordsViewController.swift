//
//  RecordsViewController.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
import Combine

class RecordsViewController: UIViewController {
    @IBOutlet weak var recordsView: RecordsView!
    
    @IBOutlet weak var actionsView: UIStackView!
    @IBOutlet weak var actionsView_WidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var actionsView_BottomConstraint: NSLayoutConstraint!
    private var actionsView_BottomConstraint_Constant: CGFloat = 0
    
    @IBOutlet weak var addToBagButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton?
    @IBOutlet weak var doneButton: UIButton?
    @IBOutlet weak var chatButton: UIButton?
    
    @IBOutlet weak var plantInstructionLabel: UILabel?
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setup() {
        // Cache the original constant for the actions view bottom constraint
        actionsView_BottomConstraint_Constant = actionsView_BottomConstraint.constant
        
        // Set up the cancel button
        cancelButton?.tintColor = .darkGray
        
        updateActions()
        
        // When the selected record changes, update the actions
        recordsView.$selectedRecord
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedRecord in
                self?.updateActions(for: selectedRecord)
            }.store(in: &cancellables)
        
        // When the configured use case changes, update the actions
        Settings.shared.$useCase
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] useCase in
                self?.updateActions(for: useCase)
            }.store(in: &cancellables)
        

    }
    
    var records: [Database.Record] {
        get {
            return recordsView.records
        }
        set {
            recordsView.records = newValue
        }
    }
    
    // MARK: - View Lifecycle
    
    private var viewIsShowing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewIsShowing = true
        updateActions()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewIsShowing = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // MARK: - Actions
    
    private func updateActions() {
        updateActions(for: Settings.shared.useCase)
        updateActions(for: recordsView.selectedRecord)
    }
    
    private func updateActions(for useCase: Settings.UseCase) {
        updateActions(for: recordsView.selectedRecord)
    }
    
    private func updateActions(for selectedRecord: Database.Record?) {
        addToBagButton.isHidden = true
        cancelButton?.isHidden = true
        
        if selectedRecord is Database.Plant {
            // For plants, show both Done and Chat buttons
            doneButton?.isHidden = (selectedRecord == nil)
            doneButton?.setTitle("Done", for: .normal)
            chatButton?.isHidden = (selectedRecord == nil)
        } else {
            // For other items, show only Done button
            doneButton?.isHidden = (selectedRecord == nil)
            doneButton?.setTitle("Done", for: .normal)
            chatButton?.isHidden = true
        }
        
        // Update navigation bar close button
        updateNavigationBarCloseButton(for: selectedRecord)
        
        // When the actions view has no visible actions, remove the offset from it's bottom
        // constraint so that the records view will be offset from the bottom a standard amount.
        let visibleActionsCount = actionsView.arrangedSubviews.filter({ $0.isHidden == false }).count
        actionsView_BottomConstraint.constant = visibleActionsCount == 0 ? 0 : actionsView_BottomConstraint_Constant
        // Set the width of the actions bar based on the screen width and number of visible actions.
        let isWidescreen = view.bounds.width > 500
        let widescreenWidth: CGFloat = {
            if visibleActionsCount == 1 { return 300 }
            else if visibleActionsCount == 2 { return 390 }
            else { return 450 }
        }()
        actionsView_WidthConstraint.constant = isWidescreen ? widescreenWidth : view.bounds.width - 32
    }
    

    

    

    
    @IBAction func cancel(_ sender: UIButton) {
        records = []
    }
    
    @IBAction func openPlantChat(_ sender: UIButton) {
        guard let selectedPlant = recordsView.selectedRecord as? Database.Plant else {
            return
        }
        
        let plantChatVC = PlantChatViewController(plant: selectedPlant)
        plantChatVC.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
        plantChatVC.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        
        present(plantChatVC, animated: true)
    }
    
    // MARK: - Navigation Bar
    
    private func updateNavigationBarCloseButton(for selectedRecord: Database.Record?) {
        if selectedRecord != nil {
            // Show close button when viewing plant/item details
            let closeButton = UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain,
                target: self,
                action: #selector(closeButtonTapped)
            )
            closeButton.tintColor = .white
            navigationItem.leftBarButtonItem = closeButton
        } else {
            // Hide close button when in camera view
            navigationItem.leftBarButtonItem = nil
        }
    }
    
    @objc private func closeButtonTapped() {
        records = []
    }
    

    
    // MARK: - Full Screen
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
