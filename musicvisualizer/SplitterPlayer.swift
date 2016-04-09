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
    
    var buffer_1: AVAudioPCMBuffer!
    var buffer_2: AVAudioPCMBuffer!
    var buffer_3: AVAudioPCMBuffer!
    var buffer_4: AVAudioPCMBuffer!
    var buffer_5: AVAudioPCMBuffer!
    var buffer_6: AVAudioPCMBuffer!
    var buffer_7: AVAudioPCMBuffer!
    var buffer_8: AVAudioPCMBuffer!
    
    let FFT_size:UInt32 = 1024
    
    var sample_rate: Double?
    var file_length: Int = 0
    
    func readFilesIntoNodes( file_name: String, file_extension: String ) {
        
        //Loading the file into a buffer
        let url = NSBundle.mainBundle().URLForResource(file_name, withExtension: file_extension)
        let file = try! AVAudioFile(forReading: url!)
        let format = AVAudioFormat(commonFormat: .PCMFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: file.fileFormat.channelCount, interleaved: false)
        master_buffer = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: UInt32(file.length))
        try! file.readIntoBuffer(master_buffer!)
        
        //Initialize sub_buffers
        buffer_1 = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: FFT_size)
        buffer_2 = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: FFT_size)
        buffer_3 = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: FFT_size)
        buffer_4 = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: FFT_size)
        buffer_5 = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: FFT_size)
        buffer_6 = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: FFT_size)
        buffer_7 = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: FFT_size)
        buffer_8 = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: FFT_size)
        
        //Record File Information
        self.sample_rate = file.fileFormat.sampleRate
        self.file_length = Int(file.length)
        
        //Connecting player node to the audio engine and starting it
        let mixer = audio_engine.mainMixerNode
        audio_engine.attachNode(master_player)
        audio_engine.connect(master_player, to: mixer, format: format)
        try! audio_engine.start()
        

        //Schedule the node when to start playing
        master_player.scheduleBuffer(master_buffer!, atTime: nil, options: .Loops, completionHandler: nil)
        
        //Initialize Volume
        master_player.volume = 1.0
    }
    
    func playNodes(){
        //master_player.play()
    }
    
    //Splits master_buffer into its frequencies
    func split_audio_into_subnodes(){
        
        let original_data = Array(UnsafeBufferPointer(start: master_buffer!.floatChannelData[0], count:Int(master_buffer!.frameLength)))
        
        //Must be a power of two, this is the size of the sample we take of the audio at a time
        let FFT_size = 1024
        
        for i in 0...(file_length/FFT_size){
            let temp = fft( Array(UnsafeBufferPointer(start: master_buffer!.floatChannelData[i*FFT_size], count:((i+1)*FFT_size) - 1 )))
            for j in 0...(FFT_size-1){
                //master_buffer!.floatChannelData.memory[(i*FFT_size)+j] = temp[j]
                buffer_1.floatChannelData.memory[(i*FFT_size)+j] = temp[0][j]
                buffer_2.floatChannelData.memory[(i*FFT_size)+j] = temp[1][j]
                buffer_3.floatChannelData.memory[(i*FFT_size)+j] = temp[2][j]
                buffer_4.floatChannelData.memory[(i*FFT_size)+j] = temp[3][j]
                buffer_5.floatChannelData.memory[(i*FFT_size)+j] = temp[4][j]
                buffer_6.floatChannelData.memory[(i*FFT_size)+j] = temp[5][j]
                buffer_7.floatChannelData.memory[(i*FFT_size)+j] = temp[6][j]
                buffer_8.floatChannelData.memory[(i*FFT_size)+j] = temp[7][j]
            }
        }
        
        let new_data = fft(original_data)
        
        for i in 0...file_length-1{
            master_buffer!.floatChannelData.memory[i] = new_data[i]
        }
    }
    
    public func fft(input: [Float]) -> [Float] {
        var real = [Float](input)
        var imaginary = [Float](count: input.count, repeatedValue: 0.0)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imaginary)
        var out: [Float]
        let length = vDSP_Length(floor(log2(Float(input.count))))
        let radix = FFTRadix(kFFTRadix2)
        let weights = vDSP_create_fftsetup(length, radix)
        vDSP_fft_zip(weights, &splitComplex, 1, length, FFTDirection(FFT_FORWARD))
        
        
        
        
        vDSP_fft_zip(weights, &splitComplex, 1, length, FFTDirection(FFT_INVERSE))
        
        var magnitudes = [Float](count: input.count, repeatedValue: 0.0)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(input.count))

        var normalizedMagnitudes = [Float](count: input.count, repeatedValue: 0.0)
        vDSP_vsmul(magnitudes.map{sqrt($0)}, 1, [1 / Float(input.count)], &normalizedMagnitudes, 1, vDSP_Length(input.count))
        
        vDSP_destroy_fftsetup(weights)
        
        return normalizedMagnitudes
    }
    
}