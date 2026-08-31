cmake_minimum_required(VERSION 3.21)

find_package(Qt6 REQUIRED COMPONENTS Core Sql Qml Quick Network Test)

# ── Shared engine/database sources (no GUI, no QML module) ────
set(ENGINE_SOURCES
    ${CMAKE_SOURCE_DIR}/src/engine/FormulaEngine.h
    ${CMAKE_SOURCE_DIR}/src/engine/FormulaEngine.cpp
    ${CMAKE_SOURCE_DIR}/src/engine/LiquidationEngine.h
    ${CMAKE_SOURCE_DIR}/src/engine/LiquidationEngine.cpp
    ${CMAKE_SOURCE_DIR}/src/engine/QuincenaAggregator.h
    ${CMAKE_SOURCE_DIR}/src/engine/QuincenaAggregator.cpp
    ${CMAKE_SOURCE_DIR}/src/database/DatabaseManager.h
    ${CMAKE_SOURCE_DIR}/src/database/DatabaseManager.cpp
    ${CMAKE_SOURCE_DIR}/src/services/ExportService.h
    ${CMAKE_SOURCE_DIR}/src/services/ExportService.cpp
    ${CMAKE_SOURCE_DIR}/src/services/UpdateService.h
    ${CMAKE_SOURCE_DIR}/src/services/UpdateService.cpp
    ${CMAKE_SOURCE_DIR}/src/controllers/AppController.h
    ${CMAKE_SOURCE_DIR}/src/controllers/AppController.cpp
    ${CMAKE_SOURCE_DIR}/src/models/CategoryModel.h
    ${CMAKE_SOURCE_DIR}/src/models/CategoryModel.cpp
    ${CMAKE_SOURCE_DIR}/src/models/CellModel.h
    ${CMAKE_SOURCE_DIR}/src/models/CellModel.cpp
    ${CMAKE_SOURCE_DIR}/src/models/ChartCellModel.h
    ${CMAKE_SOURCE_DIR}/src/models/ChartCellModel.cpp
    ${CMAKE_SOURCE_DIR}/src/models/CustomFunctionModel.h
    ${CMAKE_SOURCE_DIR}/src/models/CustomFunctionModel.cpp
    ${CMAKE_SOURCE_DIR}/src/models/EmployeeModel.h
    ${CMAKE_SOURCE_DIR}/src/models/EmployeeModel.cpp
    ${CMAKE_SOURCE_DIR}/src/models/EmployeeVarsModel.h
    ${CMAKE_SOURCE_DIR}/src/models/EmployeeVarsModel.cpp
    ${CMAKE_SOURCE_DIR}/src/models/GlobalVarsModel.h
    ${CMAKE_SOURCE_DIR}/src/models/GlobalVarsModel.cpp
    ${CMAKE_SOURCE_DIR}/src/models/ReceiptHistoryModel.h
    ${CMAKE_SOURCE_DIR}/src/models/ReceiptHistoryModel.cpp
    ${CMAKE_SOURCE_DIR}/src/models/SchemaModel.h
    ${CMAKE_SOURCE_DIR}/src/models/SchemaModel.cpp
)

# ── Test executable ───────────────────────────────────────────
add_executable(LiquidacionTests
    tst_FormulaEngine.cpp
    tst_QuincenaAggregator.cpp
    tst_LiquidationEngine.cpp
    tst_DatabaseManager.cpp
    tst_ModelsAndController.cpp
    tst_UpdateService.cpp
    tst_main.cpp
    ${ENGINE_SOURCES}
)

target_include_directories(LiquidacionTests PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/engine
    ${CMAKE_SOURCE_DIR}/src/database
    ${CMAKE_SOURCE_DIR}/src/services
    ${CMAKE_SOURCE_DIR}/src/controllers
    ${CMAKE_SOURCE_DIR}/src/models
)

target_link_libraries(LiquidacionTests PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Sql
    Qt6::Qml
    Qt6::Quick
    Qt6::Network
    Qt6::Widgets
    Qt6::Test
    QXlsx::QXlsx
)

# Register with CTest
add_test(NAME LiquidacionTests COMMAND LiquidacionTests)
