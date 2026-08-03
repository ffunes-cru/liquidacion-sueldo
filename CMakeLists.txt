cmake_minimum_required(VERSION 3.21)
project(LiquidacionSueldos VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Suppress Qt private module warning for third-party QXlsx library
set(QT_NO_PRIVATE_MODULE_WARNING ON)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    GuiPrivate
    Quick
    QuickControls2
    Sql
    Qml
)

qt_standard_project_setup(REQUIRES 6.5)

# Set Qt QML policies
if(COMMAND qt_policy)
    qt_policy(SET QTP0004 NEW)
endif()

# Add QXlsx library
add_subdirectory(third_party/QXlsx/QXlsx)

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
    src/models/CustomFunctionModel.h
    src/models/CustomFunctionModel.cpp

    # Engine
    src/engine/FormulaEngine.h
    src/engine/FormulaEngine.cpp
    src/engine/LiquidationEngine.h
    src/engine/LiquidationEngine.cpp
    src/engine/QuincenaAggregator.h
    src/engine/QuincenaAggregator.cpp

    # Services
    src/services/ExportService.h
    src/services/ExportService.cpp

    # Controllers
    src/controllers/AppController.h
    src/controllers/AppController.cpp
)

# ── QML files ─────────────────────────────────────────────────
set(QML_FILES
    qml/main.qml

    # Views
    qml/views/EmployeesView.qml
    qml/views/CompanyView.qml
    qml/views/CategoriesView.qml
    qml/views/SchemasView.qml
    qml/views/GlobalVarsView.qml
    qml/views/CustomFunctionsView.qml
    qml/views/ReceiptStructureView.qml
    qml/views/PreviewView.qml
    qml/views/ReceiptHistoryView.qml

    # Components — Template Base
    qml/components/Theme.qml
    qml/components/StyledTextField.qml
    qml/components/StyledComboBox.qml
    qml/components/StyledButton.qml
    qml/components/StyledCheckBox.qml
    qml/components/StyledSwitch.qml
    qml/components/StyledTextArea.qml
    qml/components/StyledTabButton.qml
    qml/components/StyledSpinBox.qml
    qml/components/BadgePill.qml
    qml/components/StatusBanner.qml
    qml/components/AppDialog.qml
    qml/components/AdminActions.qml
    qml/components/KpiCard.qml
    qml/components/SectionPanel.qml
    qml/components/FormField.qml
    qml/components/FormDialog.qml
    qml/components/CrudDelegate.qml
    qml/components/ActionBar.qml
    qml/components/CrudView.qml
    qml/components/MasterDetailView.qml

    # Components — Domain-Specific
    qml/components/MoneyField.qml
    qml/components/PercentageField.qml
    qml/components/FormulaInput.qml
    qml/components/RoleSelector.qml
    qml/components/QuincenaTabBar.qml
    qml/components/VariableEditor.qml
    qml/components/PaystubSectionBlock.qml

    # Dialogs
    qml/dialogs/ConceptDialog.qml
    qml/dialogs/VariableAssistantDialog.qml
    qml/dialogs/SchemaConfigDialog.qml
    qml/dialogs/SettingsDialog.qml
    qml/dialogs/CalculationErrorDialog.qml
    qml/dialogs/AboutDialog.qml
)

qt_add_executable(${PROJECT_NAME}
    ${SOURCES}
)

# Mark Theme.qml as a singleton for the QML module
set_source_files_properties(qml/components/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "liquidacion_sueldos_app")

# Win32 GUI setup
if(WIN32 AND NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    set_target_properties(${PROJECT_NAME} PROPERTIES WIN32_EXECUTABLE TRUE)
endif()

# Copy LICENSE next to executable post-build for portable deployment
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE"
    "$<TARGET_FILE_DIR:${PROJECT_NAME}>/LICENSE"
)

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
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Qml
    QXlsx::QXlsx
)

# Install
include(GNUInstallDirs)

install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/LICENSE
    DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/${PROJECT_NAME}
)

# ── Packaging & Installer Configuration (CPack) ───────────────
set(CPACK_PACKAGE_NAME "LiquidacionSueldos")
set(CPACK_PACKAGE_VENDOR "LiquidacionSueldos Team")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Sistema de Liquidación de Sueldos con Motor de Fórmulas Dinámico")
set(CPACK_PACKAGE_VERSION_MAJOR 1)
set(CPACK_PACKAGE_VERSION_MINOR 0)
set(CPACK_PACKAGE_VERSION_PATCH 0)
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")

include(CPack)

