//
//  SplitterPlayer.swift
//  EqualizerKH
//
//  Created by Kenny Hartwig on 2016-04-07.
//  Copyright © 2016 Kenny Hartwig. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate

class SplitterPlayer : NSObject {
    
    
    //Player to controller the audio
    var audio_engine: AVAudioEngine = AVAudioEngine()
    var master_player: AVAudioPlayerNode = AVAudioPlayerNode()
    var master_buffer: AVAudioPCMBuffer?

    var test_buffer: AVAudioPCMBuffer?
    var test_player: AVAudioPlayerNode = AVAudioPlayerNode()
    
    var sub_buffers: [AVAudioPCMBuffer] = []
    var sub_players: [AVAudioPlayerNode] = []
    
    var FFT_size = 1048576
    var format: AVAudioFormat!
    
    var sample_rate: Double?
    var file_length: Int = 0
    var original_file_length: Int = 0
    
    
    func readFilesIntoNodes( file_name: String, file_extension: String ) {
        
        //Loading the file into a buffer
        let url = NSBundle.mainBundle().URLForResource(file_name, withExtension: file_extension)
        let file = try! AVAudioFile(forReading: url!)
        format = AVAudioFormat(commonFormat: .PCMFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: file.fileFormat.channelCount, interleaved: false)


        // Set FFT_size
        self.FFT_size = find_highest_2power(Int(file.length))/4
        
        //Recalibrate framesize to fit audiofile for FFT computation
        let frame_size = UInt32(FFT_size*(Int(file.length)/FFT_size))
 
        //Record File Information and set FFT_Size
        self.sample_rate = file.fileFormat.sampleRate
        self.file_length = Int(frame_size)
        self.original_file_length = Int(file.length)
        
        master_buffer = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: UInt32(frame_size))
        try! file.readIntoBuffer(master_buffer!)
        
        //Initialize sub_buffers
        let file2 = try! AVAudioFile(forReading: url!)
        test_buffer = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: UInt32(frame_size))
        try! file2.readIntoBuffer(test_buffer!)
        
        for i in 0...7{
            let temp_file = try! AVAudioFile(forReading: url!)
            sub_buffers.append(AVAudioPCMBuffer(PCMFormat: format, frameCapacity: UInt32(frame_size)))
            try! temp_file.readIntoBuffer(sub_buffers[i])
        }
        
        //Connecting player node to the audio engine and starting it
        let mixer = audio_engine.mainMixerNode
        audio_engine.attachNode(master_player)
        audio_engine.connect(master_player, to: mixer, format: format)
        
        //Initialize sub_players
        audio_engine.attachNode(test_player)
        audio_engine.connect(test_player, to: mixer, format: format)
        
        for i in 0...7{
            sub_players.append(AVAudioPlayerNode())
            audio_engine.attachNode(sub_players[i])
            audio_engine.connect(sub_players[i], to: mixer, format: format)
        }
        
        try! audio_engine.start()
        
        
        //Schedule the node when to start playing
        master_player.scheduleBuffer(master_buffer!, atTime: nil, options: .Loops, completionHandler: nil)
        test_player.scheduleBuffer(test_buffer!, atTime: nil, options: .Loops, completionHandler: nil)
        
        //Intialize Volume
        master_player.volume = 1.0
        test_player.volume = 1.0
    
    }
    
    // Starts playing the nodes containing the different frequency band data
    func playNodes(){

        //This loop will sync all band to play at the same time
        var start_time:[AVAudioTime]?
        for i in 0...7{
            if (start_time == nil){
                let delay:Float = 0.1
                let start_time_sample:AVAudioFramePosition = sub_players[i].lastRenderTime!.sampleTime + AVAudioFramePosition(delay * Float(self.sample_rate!))
                start_time = [AVAudioTime(sampleTime: start_time_sample, atRate: self.sample_rate!)]
            }
            
            sub_players[i].playAtTime(start_time![0])
        }
    }
    
    func pauseNodes(){
        for i in 0...7{
            sub_players[i].pause()
        }
    }
    
    //Splits master_buffer into its frequencies and places that data into seperate buffers
    func split_audio_into_subnodes(){
        
        //Original data stored in a array to work with
        let original_data = Array(UnsafeBufferPointer(start: master_buffer!.floatChannelData[0], count:Int(master_buffer!.frameLength)))
        
        print("file_length: \(file_length) \n FFT_size: \(FFT_size) \n divided: \(file_length/FFT_size) \n")
        
        // This will split the file into segments of size FFT_size
        for i in 0...((file_length/FFT_size)-1){
            
            //Take original data and store in temp container of length FFT_size
            var temp =  [Float](count: FFT_size, repeatedValue: 0.0)
            for k in 0...(FFT_size-1){
                temp[k] = original_data[(i*FFT_size)+k]
            }
            
            print("Audio segment \(i)")
            
            //For each frequency band perform FFT on the same audio data stored in temp
            for j in 0...7{
                
                let new_data_seg = fft(temp, band:j)
                
                //Change data for all point samples within the segment
                for k in 0...(FFT_size-1){
                    sub_buffers[j].floatChannelData.memory[(i*FFT_size)+k] = new_data_seg[0][k]
                }
            }
        }
        
        print("SCHEDULING sub player with sub_buffer")
        
        // Attach Sub buffers to nodes
        for i in 0...7{
            sub_players[i].scheduleBuffer(sub_buffers[i], atTime: nil, options: .Loops, completionHandler: nil)
            sub_players[i].volume = 1.0
        }
    }
    
    internal func fft(input: [Float], band: Int) -> [[Float]] {
        var real = [Float](input)
        var imaginary = [Float](count: input.count, repeatedValue: 0.0)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imaginary)
        let length = vDSP_Length(floor(log2(Float(input.count))))
        let radix = FFTRadix(kFFTRadix2)
        let weights = vDSP_create_fftsetup(length, radix)
        vDSP_fft_zip(weights, &splitComplex, 1, length, FFTDirection(FFT_FORWARD))  //FFT transforms the data

        var magnitudes = [Float](count: input.count, repeatedValue: 0.0)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(input.count))
        
        var normalizedMagnitudes = [Float](count: input.count, repeatedValue: 0.0)
        vDSP_vsmul(magnitudes.map{sqrt($0)}, 1, [2.0 / Float(input.count)], &normalizedMagnitudes, 1, vDSP_Length(input.count))
        
        //The input count is stored as a float to compute the % of data needed for a frequency range
        let ic = Float(input.count)
        
        let base_bandwith = Float(62.0/44100.0) //0.14% of the bins are in the 0-62Hz range
        
        if (band == 0){                                     //Delete frequency data not in bottom range to get bottom data
            let bandwith_end_index = Int(base_bandwith*ic)
        
            for i in bandwith_end_index+2...(input.count-(bandwith_end_index+2)){
                splitComplex.realp[i] = 0
                splitComplex.imagp[i] = 0
            }
        }
        else if (band < 8 && band > 0){                     //Delete frequency data not in the corresponding band range
            
            let power_of2 = powf(2, Float(band-1))
            
            
            let start = Int(base_bandwith * power_of2 * ic)
            let end = Int(base_bandwith * 2 * power_of2 * ic)
            
            for i in end+2...(input.count-(end+2)){
                splitComplex.realp[i] = 0
                splitComplex.imagp[i] = 0
            }
            
            for i in 1..<(start){
                splitComplex.realp[i] = 0
                splitComplex.imagp[i] = 0
                splitComplex.realp[input.count-i] = 0
                splitComplex.imagp[input.count-i] = 0
            }
        }
        else
        {
            print("ERROR: Band requested is out of range") //Message to programmer if fft is used wrong
        }

        
        
        vDSP_fft_zip(weights, &splitComplex, 1, length, FFTDirection(FFT_INVERSE))  //Inverse the data to get back audio wave
        
        //var magnitudes = [Float](count: input.count, repeatedValue: 0.0)
        //vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(input.count))
        
        var outputValues = [Float](count: input.count, repeatedValue: 0.0)
        vDSP_vsmul(splitComplex.realp, 1, [1 / Float(input.count)], &outputValues, 1, vDSP_Length(input.count))
        
        vDSP_destroy_fftsetup(weights)
        
        return [outputValues]
    }
    
    //Function that returns the highest power of 2 that is less than the input number
    internal func find_highest_2power(number: Int ) -> Int{
        if (number < 8){
            return 0
        }
        
        var power_of_2 = 8
        while( 2*power_of_2 <= number && power_of_2 <= 8388608){
            power_of_2 = power_of_2*2
        }
        
        return power_of_2
    }
}