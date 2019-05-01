//
//  ViewController.swift
//  BluePer
//
//  Created by JiaCheng on 2019/5/1.
//  Copyright © 2019 JiaCheng. All rights reserved.
//

//教程网址: http://www.cocoachina.com/ios/20180117/21889.html?utm_source=tuicool&utm_medium=referral

import UIKit
import CoreBluetooth

class ViewController: UIViewController {
    private var peripheralManager: CBPeripheralManager?
    private var characteristic: CBMutableCharacteristic?
    
    //UUID的字符串也要符合16进制的貌似[Facepalm]
    private let Service_UUID: String = "AAA1"
    private let Characteristic_UUID: String = "BBB1"
    
    @IBOutlet weak var updateDataView: UITextView!
    @IBOutlet weak var receiveDataView: UITextView!
    
    var leftBarItem: UIBarButtonItem!
    
    var toSendOrUpdateString = "empty data"
    var receivedString: String = "" {
        didSet {
            DispatchQueue.main.async {
                self.receiveDataView.text = self.receivedString
                self.receiveDataView.scrollRangeToVisible(NSRange(location:self.receiveDataView.text.lengthOfBytes(using: .utf8), length: 1))
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 创建外设管理器，会回调peripheralManagerDidUpdateState方法
        peripheralManager = CBPeripheralManager(delegate: self, queue: DispatchQueue.global())
        
        let rightBarItem = UIBarButtonItem(title: "Update", style: .plain, target: self, action: #selector(didClickPost))
        navigationItem.rightBarButtonItem = rightBarItem
        leftBarItem = UIBarButtonItem(title: "Advertise", style: .plain, target: self, action: #selector(advertiseAct))
        leftBarItem.tintColor = .blue
        navigationItem.leftBarButtonItem = leftBarItem
        
        updateDataView.delegate = self
    }
}

// 遵守CBPeripheralManagerDelegate协议
extension ViewController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .unknown:
            print("未知的")
        case .unauthorized:
            print("未验证")
        case .poweredOff:
            print("未启动")
        case .unsupported:
             print("不支持")
        case .resetting:
            print("重置中")
        case .poweredOn:
            print("可用")
            
            // 创建Service（服务）和Characteristics（特征）
            setupServiceAndCharacteristics()
            // 根据服务的UUID开始广播
            //被连接成功后会自动关闭广播吗，好像没有被连接成功后的回调方法啊，但时候关闭广播的方法的self.peripheralManager?.stopAdvertising(),所以呢？
//            self.peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [CBUUID(string: Service_UUID)], CBAdvertisementDataLocalNameKey: "JiaChengBt"])
//            self.peripheralManager?.stopAdvertising()
        @unknown default:
            break
        }
    }
    
    @objc func advertiseAct() {
        if leftBarItem.title == "Advertise" {
            self.peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [CBUUID(string: Service_UUID)], CBAdvertisementDataLocalNameKey: "JiaCheng.Bt"])
            leftBarItem.title = "Stop"
            leftBarItem.tintColor = .red
        } else if leftBarItem.title == "Stop" {
            self.peripheralManager?.stopAdvertising()
            leftBarItem.title = "Advertise"
            leftBarItem.tintColor = .blue
        }
    }
    
    /** 创建服务和特征
     注意：swift中枚举的按位运算 '|' 要用[.read, .write, .notify]这种形式
     */
    func setupServiceAndCharacteristics() {
        let serviceID = CBUUID(string: Service_UUID)
        let service = CBMutableService(type: serviceID, primary: true)
        let characteristicID = CBUUID(string: Characteristic_UUID)
        let characteristic = CBMutableCharacteristic(type: characteristicID, properties: [.write, .read, .notify], value: nil, permissions: [.readable, .writeable])
        
        service.characteristics = [characteristic]
        self.peripheralManager?.add(service)
        self.characteristic = characteristic
    }
    
    /** 通过固定的特征发送数据到中心设备  主动给中心设备发送数据 , 对应此处的toSendOrUpdateString*/
    @objc func didClickPost() {
        peripheralManager?.updateValue(toSendOrUpdateString.data(using: .utf8)!, for: self.characteristic!, onSubscribedCentrals: nil)
    }
    
    /** 中心设备读取数据的时候回调 , 对应此处的toSendOrUpdateString*/
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {        //非常要注意的一点，这里的数据需要马上返回给中心设备，又由于我这个peripheralManagerDelegate不是在主线程的，所以从textview中读取数据需要dispatchqueue，但是不论我这边是sync还是async，它都感觉可能会卡住，所以中心设备read之后数据传不过去的。没办法，我只能给textview一个delegate，等用户每一次输入完，我都先直接把数值存起来。
        request.value = self.toSendOrUpdateString.data(using: .utf8)
        // 成功响应请求
        peripheral.respond(to: request, withResult: .success)
    }
    
    /** 中心设备写入数据的时候回调 , 对应此处的receivedString*/
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        if let request = requests.last {
//            let valueData = request.value!
//            let data = NSData(data: valueData)
//            print(data.description)
//            print(String(data: request.value!, encoding: .utf8))
            receivedString += String(data: request.value!, encoding: .utf8)! + "\n"
            // 成功响应请求
            peripheral.respond(to: request, withResult: .success)
        }
    }
    
    /** 中心设备订阅成功的时候回调 */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("\(#function) 订阅成功回调")
    }
    
    /** 中心设备取消订阅的时候回调 */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("\(#function) 取消订阅回调")
    }
    
}

extension ViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        self.toSendOrUpdateString = self.updateDataView.text
        if self.toSendOrUpdateString == "" {
            self.toSendOrUpdateString = "empty data"
        }
    }
}

