build-maps:
	lua build_map.lua

generate-love: 
	rm -rf build/sokamoka.love
	zip build/sokamoka.love -r * -x build/**\*
	
generate-appimage: generate-love
	rm -rf build/sokamoka-x86_64.AppImage
	chmod +x build/appimage/bin/*
	rm -rf build/appimage/game.love
	cp build/sokamoka.love build/appimage/game.love
	appimagetool build/appimage/ build/sokamoka-x86_64.AppImage
	
run: build-maps
	love .
