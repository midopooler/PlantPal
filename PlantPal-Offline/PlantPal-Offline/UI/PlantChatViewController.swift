//
//  PlantChatViewController.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
import Combine

class PlantChatViewController: UIViewController {
    
    // MARK: - UI Components
    private let backgroundView = UIView()
    private let panelView = UIView()
    private let headerView = UIView()
    private let plantImageView = UIImageView()
    private let plantNameLabel = UILabel()
    private let plantScientificNameLabel = UILabel()
    private let dismissHandle = UIView()
    private let chatContainerView = UIView()
    private let messagesTableView = UITableView()
    private let inputContainerView = UIView()
    private let messageTextField = UITextField()
    private let sendButton = UIButton()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Properties
    private let plant: Database.Plant
    private var messages: [ChatMessage] = []
    private var panelBottomConstraint: NSLayoutConstraint!
    private var inputBottomConstraint: NSLayoutConstraint!
    private var cancellables = Set<AnyCancellable>()
    private let plantLLMService: Any
    private var isProcessingMessage = false
    
    // MARK: - Initialization
    init(plant: Database.Plant) {
        self.plant = plant
        
        // Initialize LLM service based on iOS version
        if #available(iOS 18.0, *) {
            self.plantLLMService = PlantLLMService()
        } else {
            self.plantLLMService = PlantLLMServiceFallback()
        }
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardObservers()
        setupInitialMessages()
        setupGestures()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animatePanelUp()
    }
    
    deinit {
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.clear
        
        // Background overlay
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        backgroundView.alpha = 0
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        // Main panel
        panelView.backgroundColor = UIColor.systemBackground
        panelView.layer.cornerRadius = 20
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.layer.shadowColor = UIColor.black.cgColor
        panelView.layer.shadowOffset = CGSize(width: 0, height: -2)
        panelView.layer.shadowOpacity = 0.1
        panelView.layer.shadowRadius = 8
        panelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panelView)
        
        setupHeader()
        setupChatInterface()
        setupConstraints()
    }
    
    private func setupHeader() {
        // Dismiss handle
        dismissHandle.backgroundColor = UIColor.systemGray3
        dismissHandle.layer.cornerRadius = 2.5
        dismissHandle.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(dismissHandle)
        
        // Header container
        headerView.backgroundColor = UIColor.systemBackground
        headerView.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(headerView)
        
        // Plant image
        plantImageView.image = plant.image
        plantImageView.contentMode = .scaleAspectFill
        plantImageView.layer.cornerRadius = 25
        plantImageView.clipsToBounds = true
        plantImageView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(plantImageView)
        
        // Plant name
        plantNameLabel.text = plant.name ?? "Unknown Plant"
        plantNameLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        plantNameLabel.textColor = UIColor.label
        plantNameLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(plantNameLabel)
        
        // Scientific name
        plantScientificNameLabel.text = plant.scientificName
        plantScientificNameLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        plantScientificNameLabel.textColor = UIColor.secondaryLabel
        plantScientificNameLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(plantScientificNameLabel)
    }
    
    private func setupChatInterface() {
        // Chat container
        chatContainerView.backgroundColor = UIColor.systemBackground
        chatContainerView.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(chatContainerView)
        
        // Messages table view
        messagesTableView.backgroundColor = UIColor.systemBackground
        messagesTableView.separatorStyle = .none
        messagesTableView.delegate = self
        messagesTableView.dataSource = self
        messagesTableView.register(ChatMessageCell.self, forCellReuseIdentifier: "ChatMessageCell")
        messagesTableView.translatesAutoresizingMaskIntoConstraints = false
        chatContainerView.addSubview(messagesTableView)
        
        // Input container
        inputContainerView.backgroundColor = UIColor.systemBackground
        inputContainerView.layer.borderColor = UIColor.systemGray4.cgColor
        inputContainerView.layer.borderWidth = 1
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(inputContainerView)
        
        // Message text field
        messageTextField.placeholder = "Ask about your plant..."
        messageTextField.borderStyle = .roundedRect
        messageTextField.backgroundColor = UIColor.systemGray6
        messageTextField.delegate = self
        messageTextField.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(messageTextField)
        
        // Send button
        sendButton.setTitle("Send", for: .normal)
        sendButton.backgroundColor = UIColor.systemBlue
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.layer.cornerRadius = 8
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(sendButton)
        
        // Loading indicator
        loadingIndicator.color = UIColor.white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        // Background
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Panel
        panelBottomConstraint = panelView.topAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.75),
            panelBottomConstraint
        ])
        
        // Dismiss handle
        NSLayoutConstraint.activate([
            dismissHandle.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 8),
            dismissHandle.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
            dismissHandle.widthAnchor.constraint(equalToConstant: 40),
            dismissHandle.heightAnchor.constraint(equalToConstant: 5)
        ])
        
        // Header
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: dismissHandle.bottomAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        // Plant image
        NSLayoutConstraint.activate([
            plantImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            plantImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            plantImageView.widthAnchor.constraint(equalToConstant: 50),
            plantImageView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Plant labels
        NSLayoutConstraint.activate([
            plantNameLabel.leadingAnchor.constraint(equalTo: plantImageView.trailingAnchor, constant: 12),
            plantNameLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            plantNameLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 15),
            
            plantScientificNameLabel.leadingAnchor.constraint(equalTo: plantNameLabel.leadingAnchor),
            plantScientificNameLabel.trailingAnchor.constraint(equalTo: plantNameLabel.trailingAnchor),
            plantScientificNameLabel.topAnchor.constraint(equalTo: plantNameLabel.bottomAnchor, constant: 2)
        ])
        
        // Chat container
        NSLayoutConstraint.activate([
            chatContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            chatContainerView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor),
            chatContainerView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor),
            chatContainerView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor)
        ])
        
        // Messages table view
        NSLayoutConstraint.activate([
            messagesTableView.topAnchor.constraint(equalTo: chatContainerView.topAnchor),
            messagesTableView.leadingAnchor.constraint(equalTo: chatContainerView.leadingAnchor),
            messagesTableView.trailingAnchor.constraint(equalTo: chatContainerView.trailingAnchor),
            messagesTableView.bottomAnchor.constraint(equalTo: chatContainerView.bottomAnchor)
        ])
        
        // Input container
        inputBottomConstraint = inputContainerView.bottomAnchor.constraint(equalTo: panelView.bottomAnchor)
        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor),
            inputContainerView.heightAnchor.constraint(equalToConstant: 80),
            inputBottomConstraint
        ])
        
        // Text field and button
        NSLayoutConstraint.activate([
            messageTextField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            messageTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),
            messageTextField.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            messageTextField.heightAnchor.constraint(equalToConstant: 44),
            
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60),
            sendButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor)
        ])
    }
    
    private func setupGestures() {
        // Background tap to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        backgroundView.addGestureRecognizer(tapGesture)
        
        // Pan gesture for dismissal
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureHandler(_:)))
        panelView.addGestureRecognizer(panGesture)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func setupInitialMessages() {
        let welcomeMessage = ChatMessage(
            text: "Hi! I'm here to help you with your \(plant.name ?? "plant"). Ask me anything about plant care, watering schedules, or any issues you're experiencing!",
            isFromUser: false
        )
        messages.append(welcomeMessage)
        
        // Add some suggested questions
        addSuggestedQuestions()
    }
    
    private func addSuggestedQuestions() {
        let suggestions = [
            "How often should I water this plant?",
            "What's the best lighting for this plant?",
            "Is this plant safe for pets?",
            "How do I know if my plant is healthy?"
        ]
        
        // We'll implement suggested question bubbles later
    }
    
    // MARK: - Animations
    private func animatePanelUp() {
        panelBottomConstraint.constant = -view.bounds.height * 0.75
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.backgroundView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }
    
    private func animatePanelDown(completion: @escaping () -> Void) {
        panelBottomConstraint.constant = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.backgroundView.alpha = 0
            self.view.layoutIfNeeded()
        } completion: { _ in
            completion()
        }
    }
    
    // MARK: - Actions
    @objc private func backgroundTapped() {
        dismissChat()
    }
    
    @objc private func panGestureHandler(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                panelBottomConstraint.constant = -view.bounds.height * 0.75 + translation.y
                view.layoutIfNeeded()
            }
        case .ended:
            if translation.y > 100 || velocity.y > 500 {
                dismissChat()
            } else {
                // Snap back
                animatePanelUp()
            }
        default:
            break
        }
    }
    
    @objc private func sendMessage() {
        guard let text = messageTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              !isProcessingMessage else { return }
        
        // Set loading state
        isProcessingMessage = true
        setLoadingState(true)
        
        // Add user message
        let userMessage = ChatMessage(text: text, isFromUser: true)
        messages.append(userMessage)
        
        messageTextField.text = ""
        messageTextField.resignFirstResponder()
        
        // Reload and scroll to bottom
        messagesTableView.reloadData()
        scrollToBottom()
        
        // Send to LLM service
        if #available(iOS 18.0, *), let service = plantLLMService as? PlantLLMService {
            service.sendMessage(text, for: plant) { [weak self] response in
                DispatchQueue.main.async {
                    self?.isProcessingMessage = false
                    self?.setLoadingState(false)
                    
                    let botMessage = ChatMessage(text: response, isFromUser: false)
                    self?.messages.append(botMessage)
                    self?.messagesTableView.reloadData()
                    self?.scrollToBottom()
                }
            }
        } else if let fallbackService = plantLLMService as? PlantLLMServiceFallback {
            fallbackService.sendMessage(text, for: plant) { [weak self] response in
                DispatchQueue.main.async {
                    self?.isProcessingMessage = false
                    self?.setLoadingState(false)
                    
                    let botMessage = ChatMessage(text: response, isFromUser: false)
                    self?.messages.append(botMessage)
                    self?.messagesTableView.reloadData()
                    self?.scrollToBottom()
                }
            }
        }
    }
    
    private func setLoadingState(_ isLoading: Bool) {
        if isLoading {
            sendButton.setTitle("", for: .normal)
            loadingIndicator.startAnimating()
            sendButton.isEnabled = false
            messageTextField.isEnabled = false
        } else {
            sendButton.setTitle("Send", for: .normal)
            loadingIndicator.stopAnimating()
            sendButton.isEnabled = true
            messageTextField.isEnabled = true
        }
    }
    
    private func scrollToBottom() {
        guard messages.count > 0 else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        messagesTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    private func dismissChat() {
        messageTextField.resignFirstResponder()
        animatePanelDown {
            self.dismiss(animated: false)
        }
    }
    
    // MARK: - Keyboard Handling
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        inputBottomConstraint.constant = -keyboardFrame.height + view.safeAreaInsets.bottom
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        inputBottomConstraint.constant = 0
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - TableView DataSource & Delegate
extension PlantChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatMessageCell", for: indexPath) as! ChatMessageCell
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}

// MARK: - TextField Delegate
extension PlantChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }
} 