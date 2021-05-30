//
//  ContentView.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/19.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = SharedStore.listViewModel
    
    var body: some View {
        return VStack {
            Spacer().frame(width: 0, height: 3, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)

            HStack {
                Image("Itraffic-logo-text").resizable().padding(.leading, 6.02).frame(width: 89.39, height: 20) // origin: 1104 * 247
                Text("v0.1.0").foregroundColor(Color.gray).font(.system(size: 11, weight: .regular))
                Spacer()
                MenuItem(id: "menu.github", text: "Github", action: {
                    NSWorkspace.shared.open(URL(string: "https://github.com/foamzou/ITraffic-monitor-for-mac")!)
                }).padding([.trailing], 10)
                MenuItem(id: "menu.quit", text: "Quit", action: AppDelegate.quit).padding([.trailing], 30)
            }.frame(width: 380)
            
            List(0..<viewModel.items.count, id: \.self) { index in
                ProcessRow(processEntity: self.viewModel.items[index])
            }
            .frame(width: 380, height: 420)
            .padding([.top], -3)
        }.background(Color.white)

    }
}

struct ProcessRow: View {
    var processEntity: ProcessEntity
  
    var body: some View {
        let appInfo = getAppInfo(pid: processEntity.pid, name: processEntity.name)
        return HStack(spacing: 0) {
            Image(nsImage: (appInfo?.icon)!).frame(width: 16, height: 16)
            Text(appInfo?.name ?? processEntity.name).padding(3.0).frame(width: 150, height: 14, alignment: .leading).font(.system(size: 12))
            Image("Up").resizable().frame(width: 16, height: 16)
            Text(formatBytes(bytes: processEntity.outBytes)).frame(width: 90, height: 14, alignment: .leading).font(.system(size: 12))
            Image("Down").resizable().frame(width: 16, height: 16)
            Text(formatBytes(bytes: processEntity.inBytes)).frame(width: 90, height: 14, alignment: .leading).font(.system(size: 12))
        }

    }
}




struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}