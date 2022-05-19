build-maps:
	lua build_map.lua

generate-love: build-maps
	rm -rf build/sokamoka.love
	zip build/sokamoka.love -r * -x build/**\*
	
generate-appimage: generate-love
	rm -rf build/sokamoka-x86_64.AppImage
	chmod +x build/appimage/bin/*
	rm -rf build/appimage/game.love
	cp build/sokamoka.love build/appimage/game.love
	appimagetool build/appimage/ build/sokamoka-x86_64.AppImage
	
generate-windows: generate-love
	rm -rf build/sokamoka-windows.zip
	rm -rf build/windows/sokamoka.exe
	cat build/windows/love.exe build/sokamoka.love > build/windows/sokamoka.exe
	cd build/windows/; zip ../sokamoka-windows.zip -r * -x love.exe

run: build-maps
	love .
