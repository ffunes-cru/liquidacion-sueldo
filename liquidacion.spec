# -*- mode: python ; coding: utf-8 -*-

import os
from PyInstaller.utils.hooks import collect_data_files

# --- CONFIGURACIÓN DE TU PROYECTO ---
ENTRY_POINT = 'main.py'             # <-- CAMBIÁ esto por tu script de inicio (ej. 'app.py' o 'main.py')
APP_NAME = 'LiquidacionSueldos'     # Nombre del ejecutable final
ONE_FILE = False                    # False genera carpeta dist/LiquidacionSueldos/ (Evita falsos positivos de antivirus con Inno Setup)
# ------------------------------------

block_cipher = None

# Recolectamos datas necesarios de librerías complejas que a veces pierden archivos en la compilación
datas_matplotlib = collect_data_files('matplotlib')

added_files = datas_matplotlib + [
    # Si tenés plantillas de Excel (.xlsx) o archivos ODF (.odf) de base para las liquidaciones,
    # agrégalos acá de forma estática (ej: ('plantillas', 'plantillas')).
    # NOTA: NO agregues liquidacion_sueldos.db acá por la persistencia de datos.
]

a = Analysis(
    [ENTRY_POINT],
    pathex=[],
    binaries=[],
    datas=added_files,
    hiddenimports=[
        'PyQt6',
        'openpyxl',
        'odf',          # Para odfpy
        'simpleeval',
        'matplotlib.backends.backend_qtagg', # Asegura que matplotlib renderice bien en PyQt6
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter', 
        'IPython', 
        'jupyter_core' # Quitamos cosas interactivas para ahorrar espacio
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

if ONE_FILE:
    exe = EXE(
        pyz,
        a.scripts,
        a.binaries,
        a.zipfiles,
        a.datas,
        [],
        name=APP_NAME,
        debug=False,
        bootloader_ignore_signals=False,
        strip=False, # Strip desactivado para evitar advertencias/errores con DLLs de Windows y Qt
        upx=False,   # Desactivado por defecto (a veces rompe Qt si no se configura con cuidado)
        upx_exclude=[],
        runtime_tmpdir=None,
        console=False, # <-- FALSE oculta la terminal de fondo al ejecutar el programa
        disable_windowed_traceback=False,
        argv_emulation=False,
        target_arch=None,
        codesign_identity=None,
        entitlements_file=None,
    )
else:
    exe = EXE(
        pyz,
        a.scripts,
        [],
        exclude_binaries=True,
        name=APP_NAME,
        debug=False,
        bootloader_ignore_signals=False,
        strip=False,
        upx=False,
        console=False,
    )
    coll = COLLECT(
        exe,
        a.binaries,
        a.zipfiles,
        a.datas,
        strip=False,
        upx=False,
        upx_exclude=[],
        name=APP_NAME,
    )