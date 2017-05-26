//
//  ViewCreator.swift
//  Movies
//
//  Created by Göksel Köksal on 23/05/2017.
//  Copyright © 2017 GK. All rights reserved.
//

import UIKit

protocol MoviesFlowComponent: FlowNavigationPerformer { }

enum MoviesFlowID {
    case login
    case forgotPassword
    case changePassword
    case signUp
    case movieList
}

enum NavigationID {
    case fromLoginToChangePassword
    case fromLoginToForgotPassword
    case fromLoginToSignUp
    case fromMovieListToMovieDetail
    case logout
}

protocol MoviesFlow {
    static var id: MoviesFlowID { get }
}

extension MoviesFlowComponent where Self: UIViewController {
    
    func perform(_ navigation: FlowNavigation) {
        let flow = navigation.destination
        
        let vc: UIViewController?
        if let flow = flow as? LoginFlow {
            vc = LoginViewController.instantiate(with: flow)
        } else if let flow = flow as? SignUpFlow {
            vc = SignUpViewController.instantiate(with: flow)
        } else if let flow = flow as? ForgotPasswordFlow {
            vc = ForgotPasswordViewController.instantiate(with: flow)
        } else if let flow = flow as? MovieListFlow {
            vc = MovieListViewController.instantiate(with: flow)
            let nc = UINavigationController(rootViewController: vc!)
            present(nc, animated: true, completion: nil)
            return
        } else {
            vc = nil
        }
        if let safeVC = vc {
            navigationController?.pushViewController(safeVC, animated: true)
        }
    }
}
