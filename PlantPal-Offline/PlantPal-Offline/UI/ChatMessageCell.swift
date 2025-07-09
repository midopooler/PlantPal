//
//  ChatMessageCell.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit

class ChatMessageCell: UITableViewCell {
    
    // MARK: - UI Components
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let timestampLabel = UILabel()
    
    // MARK: - Properties
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = UIColor.clear
        selectionStyle = .none
        
        // Bubble view
        bubbleView.layer.cornerRadius = 18
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
        
        // Message label
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)
        
        // Timestamp label
        timestampLabel.font = UIFont.systemFont(ofSize: 12)
        timestampLabel.textColor = UIColor.secondaryLabel
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timestampLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        // Bubble constraints (will be updated based on message type)
        bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            // Bubble view
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.bottomAnchor.constraint(equalTo: timestampLabel.topAnchor, constant: -4),
            bubbleLeadingConstraint,
            bubbleTrailingConstraint,
            
            // Message label
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),
            
            // Timestamp label
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            timestampLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with message: ChatMessage) {
        messageLabel.text = message.text
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        timestampLabel.text = formatter.string(from: message.timestamp)
        
        if message.isFromUser {
            configureAsUserMessage()
        } else {
            configureAsBotMessage()
        }
    }
    
    private func configureAsUserMessage() {
        // User messages: blue bubble, right-aligned
        bubbleView.backgroundColor = UIColor.systemBlue
        messageLabel.textColor = UIColor.white
        
        // Update constraints for right alignment
        bubbleLeadingConstraint.isActive = false
        bubbleTrailingConstraint.isActive = false
        
        bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        
        bubbleLeadingConstraint.isActive = true
        bubbleTrailingConstraint.isActive = true
        
        // Timestamp alignment
        timestampLabel.textAlignment = .right
    }
    
    private func configureAsBotMessage() {
        // Bot messages: gray bubble, left-aligned
        bubbleView.backgroundColor = UIColor.systemGray5
        messageLabel.textColor = UIColor.label
        
        // Update constraints for left alignment
        bubbleLeadingConstraint.isActive = false
        bubbleTrailingConstraint.isActive = false
        
        bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60)
        
        bubbleLeadingConstraint.isActive = true
        bubbleTrailingConstraint.isActive = true
        
        // Timestamp alignment
        timestampLabel.textAlignment = .left
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Reset constraints will be handled in configure method
        bubbleLeadingConstraint?.isActive = false
        bubbleTrailingConstraint?.isActive = false
        
        // Reset text alignment
        timestampLabel.textAlignment = .left
    }
} 