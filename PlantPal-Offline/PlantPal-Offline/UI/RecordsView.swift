//
//  RecordsView.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import UIKit
import Combine

class RecordsView: UIView {
    let collectionView = CollectionView()
    let detailsLabel = UILabel()
    
    let explainerImageView = UIImageView()
    let explainerLabel = UILabel()
    
    private var cancellables = Set<AnyCancellable>()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        collectionView.backgroundColor = self.backgroundColor
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(collectionView)
        
        detailsLabel.numberOfLines = 0
        detailsLabel.textAlignment = .center
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(detailsLabel)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: self.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            detailsLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            detailsLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        
        // When the use-case settings change, update the actions
        collectionView.$selectedRecord
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedRecord in
                self?.selectedRecord = selectedRecord
            }.store(in: &cancellables)
        
        // Show the initial details and prepare the layout so that the layout will be correct
        showDetails(for: selectedRecord)
    }
    
    var records: [Database.Record] {
        get { collectionView.records }
        set { collectionView.records = newValue }
    }
    
    @Published var selectedRecord: Database.Record? {
        didSet {
            showDetails(for: selectedRecord)
        }
    }
    
    var selectedCell: CollectionView.Cell? {
        return collectionView.selectedCell
    }
    
    private func showDetails(for record: Database.Record?) {
        let attributedString = NSMutableAttributedString()
        
        if let plant = record as? Database.Plant {
            // Beautiful plant care display
            if let name = plant.name {
                attributedString.append(NSAttributedString(string: name, attributes: [
                    .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                    .foregroundColor: UIColor.label
                ]))
            }
            
            if let scientificName = plant.scientificName, !scientificName.isEmpty {
                if attributedString.length > 0 {
                    attributedString.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: 4)]))
                }
                attributedString.append(NSAttributedString(string: scientificName, attributes: [
                    .font: UIFont.italicSystemFont(ofSize: 16),
                    .foregroundColor: UIColor.secondaryLabel
                ]))
            }
            
            if let price = plant.price {
                if attributedString.length > 0 {
                    attributedString.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: 6)]))
                }
                attributedString.append(NSAttributedString(string: String(format: "$%.02f", price), attributes: [
                    .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                    .foregroundColor: UIColor.systemGreen
                ]))
            }
            
            // Care difficulty and characteristics
            if let characteristics = plant.characteristics {
                if attributedString.length > 0 {
                    attributedString.append(NSAttributedString(string: "\n\n", attributes: [.font: UIFont.systemFont(ofSize: 8)]))
                }
                
                var badges = [String]()
                badges.append("🌿 \(characteristics.difficulty)")
                if characteristics.airPurifying { badges.append("🫁 Air Purifying") }
                if characteristics.flowering { badges.append("🌸 Flowering") }
                if !characteristics.toxicToPets { badges.append("🐕 Pet Safe") }
                
                attributedString.append(NSAttributedString(string: badges.joined(separator: "  "), attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                    .foregroundColor: UIColor.systemBlue
                ]))
            }
            
            // Watering schedule
            if let watering = plant.wateringSchedule {
                if attributedString.length > 0 {
                    attributedString.append(NSAttributedString(string: "\n\n", attributes: [.font: UIFont.systemFont(ofSize: 8)]))
                }
                attributedString.append(NSAttributedString(string: "💧 WATERING", attributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.systemBlue
                ]))
                attributedString.append(NSAttributedString(string: "\n\(watering.frequency)", attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                    .foregroundColor: UIColor.label
                ]))
                attributedString.append(NSAttributedString(string: "\n\(watering.amount)", attributes: [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.secondaryLabel
                ]))
            }
            
            // Care instructions
            if let care = plant.careInstructions {
                if attributedString.length > 0 {
                    attributedString.append(NSAttributedString(string: "\n\n", attributes: [.font: UIFont.systemFont(ofSize: 8)]))
                }
                attributedString.append(NSAttributedString(string: "🌱 CARE TIPS", attributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.systemGreen
                ]))
                attributedString.append(NSAttributedString(string: "\n☀️ Light: \(care.light)", attributes: [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.label
                ]))
                attributedString.append(NSAttributedString(string: "\n🌡️ Temperature: \(care.temperature)", attributes: [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.label
                ]))
                attributedString.append(NSAttributedString(string: "\n💨 Humidity: \(care.humidity)", attributes: [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.label
                ]))
                attributedString.append(NSAttributedString(string: "\n🌿 Fertilizer: \(care.fertilizer)", attributes: [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.label
                ]))
                attributedString.append(NSAttributedString(string: "\n✂️ Pruning: \(care.pruning)", attributes: [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.label
                ]))
            }
            
        } else {
            // Regular product display
            if let title = record?.title {
                attributedString.append(NSAttributedString(string: title, attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .title1),
                    .foregroundColor: UIColor.label
                ]))
            }
            
            if let subtitle = record?.subtitle {
                if attributedString.length > 0 {
                    attributedString.append(NSAttributedString("\n"))
                }
                
                attributedString.append(NSAttributedString(string: subtitle, attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .title2),
                    .foregroundColor: UIColor.label
                ]))
            }
            
            if let details = record?.details {
                if attributedString.length > 0 {
                    attributedString.append(NSAttributedString("\n"))
                }
                
                attributedString.append(NSAttributedString(string: details, attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .title3),
                    .foregroundColor: UIColor.secondaryLabel
                ]))
            }
        }
        
        // Set the detail content
        detailsLabel.attributedText = attributedString
        detailsLabel.sizeToFit()
    }

    class CollectionView: UICollectionView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        
        init() {
            super.init(frame: .zero, collectionViewLayout: CollectionViewLayout())
            setup()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }
        
        private func setup() {
            self.register(Cell.self, forCellWithReuseIdentifier: "cell")
            self.showsHorizontalScrollIndicator = false
            self.dataSource = self
            self.delegate = self
        }
        
        var records: [Database.Record] = [] {
            didSet {
                self.reloadData()
                updateSelectedIndexPath()
            }
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return records.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! Cell
            let record = records[indexPath.item]
            cell.imageView.image = record.image
            
            return cell
        }
        
        // MARK: - Selected Item
        
        @Published private(set) var selectedRecord: Database.Record?

        var selectedCell: Cell? {
            guard let selectedIndexPath else { return nil }
            return cellForItem(at: selectedIndexPath) as? CollectionView.Cell
        }
        
        private(set) var selectedIndexPath: IndexPath? {
            didSet {
                if let selectedIndexPath {
                    let newSelectedRecord = records[selectedIndexPath.item]
                    if selectedRecord != newSelectedRecord {
                        selectedRecord = newSelectedRecord
                    }
                } else {
                    self.selectedRecord = records.count > 0 ? records[0] : nil
                }
            }
        }
        
        private func updateSelectedIndexPath() {
            if records.count == 0 {
                selectedIndexPath = nil
            } else {
                if records.count > 0 {
                    let layout = collectionViewLayout as! CollectionViewLayout
                    let contentOffsetX = self.contentOffset.x
                    let itemWidth = layout.itemSize.width
                    let itemIndex = Int(round(contentOffsetX / itemWidth))
                    let clampedItemIndex = min(max(0, itemIndex), records.count - 1)
                    
                    selectedIndexPath = IndexPath(item: clampedItemIndex, section: 0)
                } else {
                    selectedIndexPath = nil
                }
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let oldSelectedIndexPath = selectedIndexPath
            updateSelectedIndexPath()
            let newSelectedIndexPath = selectedIndexPath
            
            // Generated feedback when the selected index path changes while dragging
            if oldSelectedIndexPath != newSelectedIndexPath, self.isDragging || self.isTracking {
                generateSelectionFeedback()
            }
        }
        
        // MARK: - Haptic Feedbackb
        
        private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        
        private func generateSelectionFeedback() {
            selectionFeedbackGenerator.selectionChanged()
            selectionFeedbackGenerator.prepare()
        }
        
        // MARK: - Layout
        
        private class CollectionViewLayout: UICollectionViewLayout {
            private var contentSize: CGSize = .zero
            
            var itemSize: CGSize = .zero
            private var itemLayoutAttributes : [IndexPath: UICollectionViewLayoutAttributes] = [:]
            
            override var collectionView: CollectionView {
                get { super.collectionView as! CollectionView }
            }
            
            override var collectionViewContentSize: CGSize {
                return contentSize
            }
            
            private func itemSize(for bounds: CGRect) -> CGSize {
                // Item width
                let containerSize = bounds.size
                let numberOfItemsPerPage: Int
                // Show the item sized to for more than one item on screen at a time
                let collectionViewHeightToWidthRatio = containerSize.height / containerSize.width
                numberOfItemsPerPage = collectionViewHeightToWidthRatio <= 0.4 ? 4 : 2
                let itemWidth = containerSize.width / CGFloat(numberOfItemsPerPage)
                
                // Item size
                let recordsView = collectionView.superview as! RecordsView
                let detailsLabelSize = recordsView.detailsLabel.frame.size
                let itemHeight = containerSize.height - detailsLabelSize.height
                let itemSize = CGSize(width: max(itemWidth, 0), height: max(itemHeight, 0))
                
                return itemSize
            }
            
            override func prepare() {
                super.prepare()
                
                // Item size
                itemSize = itemSize(for: collectionView.bounds)
                
                // Left and right inset
                let xInset = (collectionView.bounds.width / 2) - (itemSize.width / 2)
                
                // Update item layout attributes
                itemLayoutAttributes.removeAll()
                let numberOfItems = collectionView.numberOfItems(inSection: 0)
                for item in 0..<numberOfItems {
                    let indexPath = IndexPath(item: item, section: 0)
                    
                    let attributes = UICollectionViewLayoutAttributes.init(forCellWith: indexPath)
                    let x = xInset + (CGFloat(item) * itemSize.width)
                    attributes.frame = CGRect(x: x, y: 0, width: itemSize.width, height: itemSize.height)
                    itemLayoutAttributes[indexPath] = attributes
                }
                
                // Content size
                let contentWidth = xInset + (CGFloat(numberOfItems) * itemSize.width) + xInset
                contentSize = CGSize(width: max(contentWidth, collectionView.bounds.width), height: collectionView.bounds.height)
            }
            
            override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
                return itemLayoutAttributes[indexPath]
            }
            
            override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
                var layoutAttributes = [UICollectionViewLayoutAttributes]()
                itemLayoutAttributes.forEach { (key: IndexPath, layoutAttribute: UICollectionViewLayoutAttributes) in
                    if layoutAttribute.frame.intersects(rect) {
                        layoutAttributes.append(layoutAttribute)
                    }
                }
                
                return layoutAttributes
            }
            
            override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
                let itemWidth = itemSize.width
                let itemIndex = round(proposedContentOffset.x / itemWidth)
                let newOffsetX = itemWidth * CGFloat(itemIndex)
                return CGPoint(x: newOffsetX, y: proposedContentOffset.y)
            }
            
            // MARK: - Changing Bounds
            
            private var isChangingSize: Bool = false
            private var oldSelectedIndexPath: IndexPath?
            
            override func prepare(forAnimatedBoundsChange oldBounds: CGRect) {
                super.prepare(forAnimatedBoundsChange: oldBounds)
                trackChangingBounds(oldBounds: oldBounds, newBounds: collectionView.bounds)
            }
            
            override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
                var targetContentOffset = proposedContentOffset
                
                // If the size is changing, return the offset for the old selected index path
                if self.isChangingSize, let selectedIndexPath = oldSelectedIndexPath {
                    let itemSize = itemSize(for: collectionView.bounds)
                    let xOffset = CGFloat(selectedIndexPath.item) * itemSize.width
                    targetContentOffset = CGPoint(x: xOffset, y: 0)
                }
                
                return targetContentOffset
            }
            
            override func finalizeAnimatedBoundsChange() {
                super.finalizeAnimatedBoundsChange()
                stopTrackingChangingBounds()
            }
            
            override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
                super.shouldInvalidateLayout(forBoundsChange: newBounds)
                
                // Track changing bounds and selected index path before the change
                trackChangingBounds(oldBounds: collectionView.bounds, newBounds: newBounds, selectedIndexPath: collectionView.selectedIndexPath)
                
                // When the bounds size changes, invalidate layout
                let sizeChanged = collectionView.bounds.size != newBounds.size
                return sizeChanged
            }
            
            private func trackChangingBounds(oldBounds: CGRect, newBounds: CGRect, selectedIndexPath: IndexPath? = nil) {
                // When the bounds size changes, start tracking changing bounds
                if newBounds.size != oldBounds.size {
                    self.isChangingSize = true
                }
                
                if let selectedIndexPath {
                    self.oldSelectedIndexPath = selectedIndexPath
                }
            }
            
            private func stopTrackingChangingBounds() {
                self.isChangingSize = false
                self.oldSelectedIndexPath = nil
            }
        }
        
        // MARK: - Cell
        
        class Cell: UICollectionViewCell {
            let imageView = UIImageView()
            
            override init(frame: CGRect) {
                super.init(frame: frame)
                setup()
            }
            
            required init?(coder: NSCoder) {
                super.init(coder: coder)
            }

            private func setup() {
                self.backgroundColor = .clear
                
                imageView.backgroundColor = .clear
                imageView.contentMode = .scaleAspectFit
                imageView.layer.shadowColor = UIColor.black.cgColor
                imageView.layer.shadowOffset = CGSize(width: 0, height: 3)
                imageView.layer.shadowOpacity = 0.5
                imageView.layer.shadowRadius = 6
                imageView.layer.masksToBounds = false
                imageView.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(imageView)
                
                NSLayoutConstraint.activate([
                    imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                    imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                    imageView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.8),
                    imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.8)
                ])
            }
        }
    }
}
