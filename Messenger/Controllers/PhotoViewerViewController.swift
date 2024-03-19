//
//  PhotoViewerViewController.swift
//  Messenger
//
//  Created by lynnguyen on 12/02/2024.
//

import UIKit
import SDWebImage

final class PhotoViewerViewController: UIViewController {

    private let url: URL
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    init(with url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)

    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Photo"
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        
        view.backgroundColor = .black
        
        view.addSubview(imageView)
        
        imageView.sd_setImage(with: url, completed: nil)
    }
    
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        imageView.frame = view.bounds
    }
    

}
