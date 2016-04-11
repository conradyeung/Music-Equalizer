//
//  ViewController.swift
//  musicvisualizer
//
//  Created by Conrad Yeung on 2016-03-09.
//  Copyright © 2016 music visualizer. All rights reserved.
//

import UIKit

class ViewController: UIViewController,UIPickerViewDataSource, UIPickerViewDelegate {
    var player = SplitterPlayer()
    var displayLink:CADisplayLink!
    var layers:[CALayer]!
    var scale: Float = 1.0
    var select: Int = 0
    var pickerDataSource = ["Band 1","Band 2","Band 3","Band 4","Band 5","Band 6","Band 7","Band 8"];
    @IBOutlet weak var bandPick: UIPickerView!
    @IBOutlet weak var VolumeSlider: UISlider!
    @IBOutlet weak var SampleRate: UILabel!
    @IBOutlet weak var FileLength: UILabel!
    @IBOutlet weak var FFTSize: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.bandPick.dataSource = self;
        self.bandPick.delegate = self;
        // Setup 8 layers for frequency bars.
        let color:CGColorRef = UIColor(red: 0, green: 0.6, blue: 0.8, alpha: 1).CGColor
        layers = [CALayer(), CALayer(), CALayer(), CALayer(), CALayer(), CALayer(), CALayer(), CALayer()]
        for n in 0...7 {
            layers[n].backgroundColor = color
            layers[n].frame = CGRectZero
            self.view.layer.addSublayer(layers[n])
        }
        var arr: [Int] = [7,6,5,4,3,2,1,0]
        // A display link calls us on every frame (60 fps).
        displayLink = CADisplayLink(target: self, selector: "onDisplayLink")
        displayLink.frameInterval = 1
        displayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)

//        var arr_out = player.fft(arr, band:0)
//        print(arr_out)
        // Do any additional setup after loading the view, typically from a nib.
        
        player.readFilesIntoNodes("Bubba_converted", file_extension: "wav")
        player.split_audio_into_subnodes()
        player.playNodes()
        SampleRate.text = "Sample Rate: " + String(player.sample_rate!) + "HZ"
        FileLength.text = "File Length: " + String(player.file_length)
        FFTSize.text = "FFT Size: " + String(player.FFT_size)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func sliderChange(sender: UISlider) {
        scale = Float(sender.value/10.0)
        player.sub_players[select].volume = scale
    }
    func onDisplayLink() {
        // Get the frequency values.
        let frequencies = UnsafeMutablePointer<Float>.alloc(8)
        for i in 0...7{
            frequencies[i] = player.sub_players[i].volume/20
            //print(frequencies[i])
        }
        // Wrapping the UI changes in a CATransaction block like this prevents animation/smoothing.
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        CATransaction.setDisableActions(true)
        
        // Set the dimension of every frequency bar.
        let originY:CGFloat = self.view.frame.size.height - 120
        let width:CGFloat = (self.view.frame.size.width - 47) / 8
        var frame:CGRect = CGRectMake(20, 0, width, 0)
        for n in 0...7 {
            //print(frequencies[n])
            frame.size.height = CGFloat(frequencies[n]) * 4000
            frame.origin.y = originY - frame.size.height
            layers[n].frame = frame
            frame.origin.x += width + 1
        }
        
        CATransaction.commit()
        frequencies.dealloc(8)
    }
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerDataSource.count;
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return pickerDataSource[row]
    }
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        select = row
        print(row)
    }
}

