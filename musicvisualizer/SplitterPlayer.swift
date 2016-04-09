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

    var sub_buffers: [AVAudioPCMBuffer] = []
    var sub_players: [AVAudioPlayerNode] = []
    
    let FFT_size:UInt32 = 1024
    var format: AVAudioFormat!
    
    var sample_rate: Double?
    var file_length: Int = 0
    
    
    func readFilesIntoNodes( file_name: String, file_extension: String ) {
        
        //Loading the file into a buffer
        let url = NSBundle.mainBundle().URLForResource(file_name, withExtension: file_extension)
        let file = try! AVAudioFile(forReading: url!)
        format = AVAudioFormat(commonFormat: .PCMFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: file.fileFormat.channelCount, interleaved: false)
        master_buffer = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: UInt32(file.length))
        try! file.readIntoBuffer(master_buffer!)
        
        //Initialize sub_buffers
        for i in 0...7{
            sub_buffers.append(AVAudioPCMBuffer(PCMFormat: format, frameCapacity: FFT_size))
        }
        
        //Record File Information
        self.sample_rate = file.fileFormat.sampleRate
        self.file_length = Int(file.length)
        
        //Connecting player node to the audio engine and starting it
        let mixer = audio_engine.mainMixerNode
        audio_engine.attachNode(master_player)
        audio_engine.connect(master_player, to: mixer, format: format)
        
        //Initialize sub_players
        for i in 0...7{
            sub_players.append(AVAudioPlayerNode())
            audio_engine.attachNode(sub_players[i])
            audio_engine.connect(sub_players[i], to: mixer, format: format)
        }
        
        try! audio_engine.start()
        

        //Schedule the node when to start playing
        master_player.scheduleBuffer(master_buffer!, atTime: nil, options: .Loops, completionHandler: nil)
        
        //Initialize Volume
        master_player.volume = 1.0
    
    
    
    }
    
    func playNodes(){
        //master_player.play()
        for i in 0...7{
            sub_players[i].play()
        }
    }
    
    //Splits master_buffer into its frequencies
    func split_audio_into_subnodes(){
        
        let original_data = Array(UnsafeBufferPointer(start: master_buffer!.floatChannelData[0], count:Int(master_buffer!.frameLength)))
        
        let FFT_size = 1024
        
        // This will split the file into segments of size FFT_size
        for i in 0...((file_length/FFT_size)-1){
            
            //For each frequency band perform FFT on the same audio
            for j in 0...7{
                
                var temp: [Float] = []
                for p in 0...(FFT_size-1){
                    temp.append(original_data[(i*FFT_size)+p])
                }
                
                let new_data_seg = fft(temp, band:j)
                
                //Change data for all point samples within the segment
                for k in 0...(FFT_size-1){
                    sub_buffers[j].floatChannelData.memory[k] = new_data_seg[k]
                }
            }
        }
        
        // Attach Sub buffers to nodes
        for i in 0...7{
            sub_players[i].scheduleBuffer(sub_buffers[i], atTime: nil, options: .Loops, completionHandler: nil)
            sub_players[i].volume = 1.0
        }
        
        
//        let new_data = fft(original_data)
//        
//        for i in 0...file_length-1{
//            master_buffer!.floatChannelData.memory[i] = new_data[i]
//        }
    }
    
    internal func fft(input: [Float], band: Int) -> [Float] {
        var real = [Float](input)
        var imaginary = [Float](count: input.count, repeatedValue: 0.0)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imaginary)
        let length = vDSP_Length(floor(log2(Float(input.count))))
        let radix = FFTRadix(kFFTRadix2)
        let weights = vDSP_create_fftsetup(length, radix)
        vDSP_fft_zip(weights, &splitComplex, 1, length, FFTDirection(FFT_FORWARD))
        if(band == 7){
            for i in 0...(7*input.count/8){
                splitComplex.realp[i] = 0
                splitComplex.imagp[i] = 0
            }
        }else if(band == 0){
            for i in (input.count/8)...(input.count-1){
                splitComplex.realp[i] = 0
                splitComplex.imagp[i] = 0
            }
        }else{
            for i in 0...(band*input.count/8){
                splitComplex.realp[i] = 0
                splitComplex.imagp[i] = 0
            }
            for i in ((band+1)*input.count/8)...(input.count-1){
                splitComplex.realp[i] = 0
                splitComplex.imagp[i] = 0
            }
        }
        
        vDSP_fft_zip(weights, &splitComplex, 1, length, FFTDirection(FFT_INVERSE))
        
        var magnitudes = [Float](count: input.count, repeatedValue: 0.0)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(input.count))
        
        var normalizedMagnitudes = [Float](count: input.count, repeatedValue: 0.0)
        vDSP_vsmul(magnitudes.map{sqrt($0)}, 1, [1 / Float(input.count)], &normalizedMagnitudes, 1, vDSP_Length(input.count))
        
        vDSP_destroy_fftsetup(weights)
        
        return normalizedMagnitudes
    }
    
}