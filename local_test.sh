docker run --rm -it -v $(pwd):/github/workspace \
    -e INPUT_MODNAME=libox_controller \
    -e INPUT_TEST_MODE=mod \
    -e INPUT_MAPGEN=singlenode \
    -e INPUT_GIT_GAME_REPO=https://github.com/minetest/minetest_game \
    -e INPUT_ENABLE_COVERAGE=true \
    -e INPUT_GIT_DEPENDENCIES="https://github.com/TheEt1234/libox https://github.com/minetest-mods/mesecons https://github.com/minetest-mods/digilines" \
    -e INPUT_ADDITIONAL_CONFIG="secure.trusted_mods=mtt,libox"\
    ghcr.io/buckaroobanzay/mtt
