//
//  LoginViewController.swift
//  Messenger
//
//  Created by lynnguyen on 12/02/2024.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import JGProgressHUD

final class LoginViewController: UIViewController {

    private let spinner = JGProgressHUD(style: .dark)
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "logo")
        return imageView
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.layer.masksToBounds = true
        field.placeholder = "Email Address..."
        
        field.leftView = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 10, height: 0)))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()
    
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.layer.masksToBounds = true
        field.placeholder = "Password..."
        
        field.leftView = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 10, height: 0)))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .link
        button.setTitle("Log In", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let facebookLoginButton: FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["email", "public_profile"]
        return button
    }()

    private let googleLogInButton = GIDSignInButton()
    
    private var loginObserver: NSObjectProtocol?
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loginObserver = NotificationCenter.default.addObserver(
            forName: .didLogInNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            
            guard let strongSelf = self else { return }
            
            strongSelf.navigationController?.dismiss(animated: true, completion: nil)
        }
        
        
        title = "Log In"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Register",
            style: .done,
            target: self,
            action: #selector(didTapRegister)
        )
        
        emailField.delegate = self
        passwordField.delegate = self
        
        facebookLoginButton.delegate = self
        
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(facebookLoginButton)
        scrollView.addSubview(googleLogInButton)
    }
    
    deinit {
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    @objc private func loginButtonTapped() {
        
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text, let password = passwordField.text,
              !email.isEmpty, !password.isEmpty, password.count >= 6 else {
            alertUserLogginError()
            return
        }
        
        spinner.show(in: view)
        
        // Firebase log in
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let strongSelf = self else {
                return
            }
            
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            guard let result = authResult, error == nil else {
                print("Failed to log in user with email: \(email)")
                return
            }
            
            let user = result.user
            
            let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
            
            DatabaseManager.shared.getDataFor(path: safeEmail) { result in
                switch result {
                case .success(let data):
                    guard let userData = data as? [String: Any],
                          let firstName = userData["first_name"] as? String,
                          let lastName = userData["last_name"] as? String else {
                        return
                    }
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")

                case .failure(let error):
                    print("failed to read data with error: \(error)")
                }
            }
            
            UserDefaults.standard.set(email, forKey: "email")
            NotificationCenter.default.post(name: .didLogInNotification, object: nil)

            print("Logged in User: \(user)")
            strongSelf.navigationController?.dismiss(animated: true, completion: nil)
        }
        
    }
    
    func alertUserLogginError() {
        let alert = UIAlertController(title: "Woops",
                                      message: "Please enter all information to log in",
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        
        present(alert, animated: true)
    }
    
    @objc private func didTapRegister() {
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        scrollView.frame = view.bounds
        
        let size = scrollView.width / 3
        imageView.frame = CGRect(x: (scrollView.width - size) / 2,
                                 y: 20 + view.safeAreaInsets.top,
                                 width: size,
                                 height: size)
        
        emailField.frame = CGRect(x: 30,
                                  y: imageView.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        
        passwordField.frame = CGRect(x: 30,
                                  y: emailField.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        
        loginButton.frame = CGRect(x: 30,
                                  y: passwordField.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        
        facebookLoginButton.frame = CGRect(x: 30,
                                  y: loginButton.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)

        googleLogInButton.frame = CGRect(x: 30,
                                  y: facebookLoginButton.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)

    }

    
}

extension LoginViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        }
        else if textField == passwordField {
            loginButtonTapped()
        }
        return true
    }
}

extension LoginViewController: LoginButtonDelegate {
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginKit.FBLoginButton) {
        // no operation
    }
    
    func loginButton(_ loginButton: FBSDKLoginKit.FBLoginButton, didCompleteWith result: FBSDKLoginKit.LoginManagerLoginResult?, error: (Error)?) {
        
        guard let token = result?.token?.tokenString else {
            print("User failed to log in with facebook")
            return
        }
        
        let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                         parameters: ["fields": "email, first_name, last_name, picture.type(large)"],
                                                         tokenString: token,
                                                         version: nil,
                                                         httpMethod: .get)
        facebookRequest.start { _, result, error in
            guard let result = result as? [String: Any], error == nil else {
                print("Failed to make facebook graph request")
                return
            }
            print("Result: \(result)")
                        
            guard let firstName = result["first_name"] as? String,
                  let lastName = result["last_name"] as? String,
                  let email = result["email"] as? String,
                  let picture = result["picture"] as? [String: Any],
                  let data = picture["data"] as? [String: Any],
                  let pictureUrl = data["url"] as? String else {
                print("Failed to get email and name from fb result")
                return
            }
            
            UserDefaults.standard.set(email, forKey: "email")
            UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
            
            DatabaseManager.shared.userExists(with: email) { exists in
                if !exists {
                    let chatUser = ChatAppUser(firstName: firstName,
                                               lastName: lastName,
                                               emailAddress: email)
                    
                    DatabaseManager.shared.insertUser(with: chatUser) { success in
                        if success {
                            guard let url = URL(string: pictureUrl) else {
                                return
                            }
                            print("Downloading data from facebook image")
                            
                            URLSession.shared.dataTask(with: url    ) { data, _, error in
                                guard let data = data, error == nil else {
                                    print("Failed to get data from Facebook")
                                    return
                                }
                                print("Got data from FB, uploading")
                                // upload Image
                                
                                let fileName = chatUser.profilePictureFileName
                                StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName) { result in
                                    switch result {
                                    case .success(let downloadUrl):
                                        UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                        print(downloadUrl)
                                    case .failure(let error):
                                        print("Storage manager error: \(error)")
                                    }
                                }

                            }.resume()
                        }
                    }
                }
            }
            
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            FirebaseAuth.Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                
                guard let strongSelf = self else {
                    return
                }
                
                guard authResult != nil, error == nil else {
                    if let error = error {
                        print("Facebook credential login failed, MFA may be needed - \(error)")
                    }
                    return
                }
                
                print("sucessfully logged user in")
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
                
            }
            
        }
        
    }
}

