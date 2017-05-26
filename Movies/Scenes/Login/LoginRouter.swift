//
//  LoginRouter.swift
//  Movies
//
//  Created by Göksel Köksal on 14/05/2017.
//  Copyright © 2017 GK. All rights reserved.
//

import UIKit

class LoginRouter: Router {
    
    unowned let flow: LoginFlow
    
    init(flow: LoginFlow) {
        self.flow = flow
    }
    
    func perform(_ segue: Segue) -> FlowNavigation? {
        guard let segue = segue as? LoginSegue else { return nil }
        switch segue {
        case .signUp:
            return FlowNavigation(SignUpFlow())
        case .login(let response):
            if response.isPasswordExpired {
                return FlowNavigation(ChangePasswordFlow())
            } else {
                let flow = MovieListFlow(service: MockMoviesService(delay: 1.5))
                return FlowNavigation(flow)
            }
        case .forgotPassword:
            return FlowNavigation(ForgotPasswordFlow())
        }
    }
}
