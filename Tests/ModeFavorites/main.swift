import Foundation
var passed=0
func check(_ v:Bool,_ name:String) { precondition(v,name); passed+=1; print("PASS "+name) }
let name="local.M8Studio.FavoriteTest."+UUID().uuidString
let defaults=UserDefaults(suiteName:name)!
defer {defaults.removePersistentDomain(forName:name)}
let store=DisplayModeFavorites(defaults:defaults)
let a=FavoriteDisplayMode(width:1920,height:1080,pixelWidth:3840,pixelHeight:2160,milliHz:59940)
let b=FavoriteDisplayMode(width:1920,height:1080,pixelWidth:1920,pixelHeight:1080,milliHz:59940)
check(store.toggle(a,for:"display-a"),"favorite saved")
check(store.modes(for:"display-a")==[a],"stable geometry and fractional rate round-trip")
check(store.modes(for:"display-b").isEmpty,"different display stays independent")
check(!a.matches(b),"HiDPI and low-resolution modes remain distinct")
check(!a.matches(FavoriteDisplayMode(width:1920,height:1080,pixelWidth:3840,pixelHeight:2160,milliHz:60000)),"59.94 and 60 remain distinct")
check(!a.matches(FavoriteDisplayMode(width:1920,height:1080,pixelWidth:3840,pixelHeight:2200,milliHz:59940)),"render height is part of identity")
check(store.toggle(a,for:"display-a") && store.modes(for:"display-a").isEmpty,"toggle removes favorite")
for index in 0..<8 {check(store.toggle(FavoriteDisplayMode(width:1920+index,height:1080,pixelWidth:3840,pixelHeight:2160,milliHz:60000),for:"limit"),"bounded favorite saved")}
check(!store.toggle(a,for:"limit") && store.modes(for:"limit").count==8,"capacity fails without losing saved modes")
check(!store.toggle(a,for:""),"missing display identity rejected")
check(!store.toggle(FavoriteDisplayMode(width:1,height:1,pixelWidth:1,pixelHeight:1,milliHz:0),for:"bad"),"invalid geometry rejected")
defaults.set(Data("not-json".utf8),forKey:"favoriteDisplayModes.corrupt")
check(store.modes(for:"corrupt").isEmpty,"corrupt preferences recover empty")
print("\(passed) favorite-mode checks passed; no display changes")
