//
//  ViewController.swift
//  musicvisualizer
//
//  Created by Conrad Yeung on 2016-03-09.
//  Copyright © 2016 music visualizer. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var player = SplitterPlayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        var arr: [Float] = [0,1,2,3,4,5,6,7]
        var arr_out = player.fft(arr)
        print(arr_out)
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    //test

}

