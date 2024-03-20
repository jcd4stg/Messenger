//
//  NewConversationViewController.swift
//  Messenger
//
//  Created by lynnguyen on 12/02/2024.
//

import UIKit
import JGProgressHUD

final class NewConversationViewController: UIViewController {
    
    public var completion: ((SearchResult) -> Void)?

    private let spinner = JGProgressHUD(style: .dark)
    
    private var users = [[String: String]]()
    
    private var results = [SearchResult]()

    private var hasFetched = false
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for Users..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(NewConversationCell.self,
                           forCellReuseIdentifier: NewConversationCell.identifier)
        return tableView
    }()
    
    private let noResultsLabel: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.numberOfLines = 0
        label.text = "No Results"
        label.textAlignment = .center
        label.textColor = .green
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground

        view.addSubview(noResultsLabel)
        view.addSubview(tableView)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        searchBar.delegate = self
                
        navigationController?.navigationBar.topItem?.titleView = searchBar
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
        
        
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.width / 4,
                                      y: (view.height - 200) / 2,
                                      width: view.width / 2,
                                      height: 200)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
}

extension NewConversationViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: NewConversationCell.identifier,
            for: indexPath
        ) as? NewConversationCell else {
            return UITableViewCell()
        }
        let model = results[indexPath.row]
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // start conversation
        let targetUserData = results[indexPath.row]
        
        dismiss(animated: true, completion: { [weak self] in
            self?.completion?(targetUserData)
        })
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}

extension NewConversationViewController: UISearchBarDelegate {
     
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return
        }
        
        searchBar.resignFirstResponder()
        

        results.removeAll()
        spinner.show(in: view)
        searchUsers(query: text)
    }
    
    private func searchUsers(query: String) {
        // check if array has firebae results
        if hasFetched {
            // if it does: filter
            filterUsers(with: query)
        } else {
            // if not, fetch then filter
            DatabaseManager.shared.getAllUsers { [weak self] result in
                switch result {
                case .success(let userCollection):
                    self?.hasFetched = true
                    self?.users = userCollection
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print("Failed to get users: \(error)")
                }
            }
        }
        
    }
    
    private func filterUsers(with term: String) {
        // update the UI: either show results or show no results
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String, 
                hasFetched else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        spinner.dismiss()
        
        let results: [SearchResult] = users.filter {
            guard let email = $0["email"], email != safeEmail else {
                return false
            }
            
            guard let name = $0["name"]?.description.lowercased() else {
                return false
            }
            
            return name.hasPrefix(term.lowercased())
        }.compactMap {
            
            guard let email = $0["email"], let name = $0["name"] else {
                return nil
            }
            
            return SearchResult(name: name, email: email)
        }
        
        self.results = results
        
        updateUI()
    }
    
    private func updateUI() {
        if results.isEmpty {
            noResultsLabel.isHidden = false
            tableView.isHidden = true
        } else {
            noResultsLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }
    
}
