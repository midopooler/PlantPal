//
//  Settings.swift
//  PlantPal-Offline
//
//  Created by Pulkit Midha on 07/07/24.
//

import Foundation
import Combine
import UIKit

class Settings: ObservableObject {
    static let shared = Settings()
    
    @Published var useCase: UseCase = .plantLookup
    @Published var frontCameraEnabled: Bool = false
    @Published var externalScreenEnabled: Bool = true
    
    @Published var endpoint: Endpoint? {
        didSet {
            updateIsLoggedIn()
        }
    }
    
    @Published var isDemoEnabled: Bool = false {
        didSet {
            let userDefaults = UserDefaults.standard
            userDefaults.setValue(isDemoEnabled, forKey: "demo_enabled")
            
            updateIsLoggedIn()
        }
    }
    
    @Published var isLoggedIn: Bool = false
    
    enum UseCase: String {
        case plantLookup = "plantLookup"
    }
    
    struct Endpoint: Equatable {
        let url: URL
        let username: String?
        let password: String?

        static func == (lhs: Endpoint, rhs: Endpoint) -> Bool {
            return lhs.url == rhs.url &&
                   lhs.username == rhs.username &&
                   lhs.password == rhs.password
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Register defaults
        UserDefaults.standard.register(defaults: [
            "front_camera_enabled": false,
            "external_screen_enabled": false,
            "use_case": UseCase.plantLookup.rawValue,
            "demo_enabled": false
        ])
        
        observeUserDefaults()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    private func observeUserDefaults() {
        let userDefaults = UserDefaults.standard
        
        // Use case
        userDefaults.publisher(for: \.use_case)
            .sink { [weak self] _ in
                self?.updateUseCase()
            }
            .store(in: &cancellables)
        
        // Front camera
        userDefaults.publisher(for: \.front_camera_enabled)
            .sink { [weak self] _ in
                 self?.updateCamera()
            }
            .store(in: &cancellables)
        
        // External screen
        userDefaults.publisher(for: \.external_screen_enabled)
            .sink { [weak self] _ in
                self?.updateExternalScreen()
            }
            .store(in: &cancellables)
        
        // Endpoint
        userDefaults.publisher(for: \.endpoint_enabled)
            .sink { [weak self] _ in
                self?.updateEndpoint()
            }
            .store(in: &cancellables)
        
        userDefaults.publisher(for: \.endpoint_url)
            .sink { [weak self] _ in
                self?.updateEndpoint()
            }
            .store(in: &cancellables)
        
        userDefaults.publisher(for: \.endpoint_username)
            .sink { [weak self] _ in
                self?.updateEndpoint()
            }
            .store(in: &cancellables)
        
        userDefaults.publisher(for: \.endpoint_password)
            .sink { [weak self] _ in
                self?.updateEndpoint()
            }
            .store(in: &cancellables)
        
        // Demo
        userDefaults.publisher(for: \.demo_enabled)
            .sink { [weak self] _ in
                self?.updateDemo()
            }
            .store(in: &cancellables)
    }
    
    private func updateUseCase() {
        let userDefaults = UserDefaults.standard
        let demoUseCaseRawValue = userDefaults.string(forKey: "use_case") ?? UseCase.plantLookup.rawValue
        let useCase = UseCase(rawValue: demoUseCaseRawValue) ?? .plantLookup
        
        if self.useCase != useCase {
            self.useCase = useCase
        }
    }
    
    private func updateCamera() {
        let userDefaults = UserDefaults.standard
        let newFrontCameraEnabled = userDefaults.bool(forKey: "front_camera_enabled")
        
        if frontCameraEnabled != newFrontCameraEnabled {
            frontCameraEnabled = newFrontCameraEnabled
        }
    }
    
    private func updateExternalScreen() {
        let userDefaults = UserDefaults.standard
        let newExternalScreenEnabled = userDefaults.bool(forKey: "external_screen_enabled")
        
        if externalScreenEnabled != newExternalScreenEnabled {
            externalScreenEnabled = newExternalScreenEnabled
        }
    }
    
    private func updateEndpoint() {
        let userDefaults = UserDefaults.standard
        var newEndpoint: Endpoint?
        
        // If the endpoint is enabled, get it's config
        if userDefaults.endpoint_enabled,
           let endpointUrl = userDefaults.endpoint_url
        {
            newEndpoint = Endpoint(
                url: endpointUrl,
                username: userDefaults.endpoint_username,
                password: userDefaults.endpoint_password
            )
        }
        
        if newEndpoint != endpoint {
            endpoint = newEndpoint
        }
    }
    
    private func updateDemo() {
        let userDefaults = UserDefaults.standard
        let isDemoEnabled = userDefaults.bool(forKey: "demo_enabled")
        
        if self.isDemoEnabled != isDemoEnabled {
            self.isDemoEnabled = isDemoEnabled
        }
    }
    
    private func updateIsLoggedIn() {
        let isDemoEnabled = self.isDemoEnabled
        let isEndpointEnabled = self.endpoint != nil
        
        isLoggedIn = isDemoEnabled || isEndpointEnabled
    }
}

extension UserDefaults {
    @objc dynamic var front_camera_enabled: Bool {
        get {
            return bool(forKey: "front_camera_enabled")
        }
        set {
            set(newValue, forKey: "front_camera_enabled")
        }
    }
    
    @objc dynamic var external_screen_enabled: Bool {
        get {
            return bool(forKey: "external_screen_enabled")
        }
        set {
            set(newValue, forKey: "external_screen_enabled")
        }
    }
    
    @objc dynamic var demo_enabled: Bool {
        get {
            return bool(forKey: "demo_enabled")
        }
        set {
            set(newValue, forKey: "demo_enabled")
        }
    }
    
    @objc dynamic var use_case: String? {
        get {
            return string(forKey: "use_case")
        }
        set {
            set(newValue, forKey: "use_case")
        }
    }
    
    @objc dynamic var endpoint_enabled: Bool {
        get {
            return bool(forKey: "endpoint_enabled")
        }
        set {
            set(newValue, forKey: "endpoint_enabled")
        }
    }

    @objc dynamic var endpoint_url: URL? {
        get {
            guard let urlString = string(forKey: "endpoint_url") else { return nil }
            return URL(string: urlString)
        }
        set {
            set(newValue?.absoluteString, forKey: "endpoint_url")
        }
    }

    @objc dynamic var endpoint_username: String? {
        get {
            return string(forKey: "endpoint_username")
        }
        set {
            set(newValue, forKey: "endpoint_username")
        }
    }

    @objc dynamic var endpoint_password: String? {
        get {
            return string(forKey: "endpoint_password")
        }
        set {
            set(newValue, forKey: "endpoint_password")
        }
    }
}
