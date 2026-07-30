cmake_minimum_required(VERSION 3.21)
project(LiquidacionSueldos VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Quick
    QuickControls2
    Sql
    Qml
)

qt_standard_project_setup(REQUIRES 6.5)

# ── Source files ──────────────────────────────────────────────
set(SOURCES
    src/main.cpp

    # Database
    src/database/DatabaseManager.h
    src/database/DatabaseManager.cpp

    # Models
    src/models/EmployeeModel.h
    src/models/EmployeeModel.cpp
    src/models/EmployeeVarsModel.h
    src/models/EmployeeVarsModel.cpp
    src/models/GlobalVarsModel.h
    src/models/GlobalVarsModel.cpp
    src/models/SchemaModel.h
    src/models/SchemaModel.cpp
    src/models/CategoryModel.h
    src/models/CategoryModel.cpp
    src/models/CellModel.h
    src/models/CellModel.cpp
    src/models/ChartCellModel.h
    src/models/ChartCellModel.cpp
    src/models/ReceiptHistoryModel.h
    src/models/ReceiptHistoryModel.cpp

    # Engine
    src/engine/FormulaEngine.h
    src/engine/FormulaEngine.cpp
    src/engine/LiquidationEngine.h
    src/engine/LiquidationEngine.cpp
    src/engine/QuincenaAggregator.h
    src/engine/QuincenaAggregator.cpp

    # Controllers
    src/controllers/AppController.h
    src/controllers/AppController.cpp
)

# ── QML files ─────────────────────────────────────────────────
set(QML_FILES
    qml/main.qml
    qml/views/EmployeesView.qml
    qml/views/CompanyView.qml
    qml/views/CategoriesView.qml
    qml/views/SchemasView.qml
    qml/views/GlobalVarsView.qml
    qml/views/ReceiptStructureView.qml
    qml/views/PreviewView.qml
    qml/views/ReceiptHistoryView.qml
)

qt_add_executable(${PROJECT_NAME}
    ${SOURCES}
)

set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "liquidacion_sueldos_app")

# Win32 GUI setup (hides command prompt console window on Windows release builds)
if(WIN32 AND NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    set_target_properties(${PROJECT_NAME} PROPERTIES WIN32_EXECUTABLE TRUE)
endif()

qt_add_qml_module(${PROJECT_NAME}
    URI LiquidacionSueldos
    VERSION 1.0
    QML_FILES ${QML_FILES}
    NO_RESOURCE_TARGET_PATH
)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Qml
)

# Install
install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
