import subprocess
import json
import time

import config.data as data

# Cache for workspace and monitor data
_last_workspace_check = 0
_last_workspace_id = -1
_last_monitor_check = 0
_monitor_cache = None
_cache_timeout = 5.0  # Cache for 5 seconds

def get_current_workspace():
    """
    Get the current workspace ID using hyprctl, with caching.
    """
    global _last_workspace_check, _last_workspace_id
    current_time = time.time()
    if current_time - _last_workspace_check < _cache_timeout:
        print(f"[{time.strftime('%H:%M:%S')}] Using cached workspace ID: {_last_workspace_id}")
        return _last_workspace_id

    try:
        result = subprocess.run(
            ["hyprctl", "activeworkspace"],
            capture_output=True,
            text=True
        )
        parts = result.stdout.split()
        for i, part in enumerate(parts):
            if part == "ID" and i + 1 < len(parts):
                _last_workspace_id = int(parts[i + 1])
                _last_workspace_check = current_time
                print(f"[{time.strftime('%H:%M:%S')}] Fetched workspace ID: {_last_workspace_id}")
                return _last_workspace_id
    except Exception as e:
        print(f"[{time.strftime('%H:%M:%S')}] Error getting current workspace: {e}")
    return -1

def get_screen_dimensions():
    """
    Get screen dimensions from hyprctl, with caching.

    Returns:
        tuple: (width, height) of the monitor containing the current workspace
    """
    global _last_monitor_check, _monitor_cache
    current_time = time.time()
    if current_time - _last_monitor_check < _cache_timeout and _monitor_cache:
        print(f"[{time.strftime('%H:%M:%S')}] Using cached monitor dimensions: {_monitor_cache}")
        return _monitor_cache

    try:
        workspace_id = get_current_workspace()
        result = subprocess.run(
            ["hyprctl", "-j", "monitors"],
            capture_output=True,
            text=True
        )
        monitors = json.loads(result.stdout)
        for monitor in monitors:
            if monitor.get("activeWorkspace", {}).get("id") == workspace_id:
                _monitor_cache = (monitor.get("width", data.CURRENT_WIDTH), monitor.get("height", data.CURRENT_HEIGHT))
                _last_monitor_check = current_time
                print(f"[{time.strftime('%H:%M:%S')}] Fetched monitor dimensions: {_monitor_cache}")
                return _monitor_cache
        if monitors:
            _monitor_cache = (monitors[0].get("width", data.CURRENT_WIDTH), monitors[0].get("height", data.CURRENT_HEIGHT))
            _last_monitor_check = current_time
            print(f"[{time.strftime('%H:%M:%S')}] Fetched fallback monitor dimensions: {_monitor_cache}")
            return _monitor_cache
    except Exception as e:
        print(f"[{time.strftime('%H:%M:%S')}] Error getting screen dimensions: {e}")
    return data.CURRENT_WIDTH, data.CURRENT_HEIGHT

def check_occlusion(occlusion_region, workspace=None):
    """
    Check if a region is occupied by any window on a given workspace.

    Parameters:
        occlusion_region: Can be one of:
            - tuple (side, size): where side is "top", "bottom", "left", or "right"
              and size is the pixel width of the region
            - tuple (x, y, width, height): The full region coordinates (legacy format)
        workspace (int, optional): The workspace ID to check. If None, the current workspace is used.

    Returns:
        bool: True if any window overlaps with the occlusion region, False otherwise.
    """
    print(f"[{time.strftime('%H:%M:%S')}] Checking occlusion for region: {occlusion_region}")
    if workspace is None:
        workspace = get_current_workspace()

    if isinstance(occlusion_region, tuple) and len(occlusion_region) == 2:
        side, size = occlusion_region
        if isinstance(side, str):
            screen_width, screen_height = get_screen_dimensions()
            if side.lower() == "bottom":
                occlusion_region = (0, screen_height - size, screen_width, size)
            elif side.lower() == "top":
                occlusion_region = (0, 0, screen_width, size)
            elif side.lower() == "left":
                occlusion_region = (0, 0, size, screen_height)
            elif side.lower() == "right":
                occlusion_region = (screen_width - size, 0, size, screen_height)

    if not isinstance(occlusion_region, tuple) or len(occlusion_region) != 4:
        print(f"[{time.strftime('%H:%M:%S')}] Invalid occlusion region format: {occlusion_region}")
        return False

    try:
        result = subprocess.run(
            ["hyprctl", "-j", "clients"],
            capture_output=True,
            text=True
        )
        clients = json.loads(result.stdout)
    except Exception as e:
        print(f"[{time.strftime('%H:%M:%S')}] Error retrieving client windows: {e}")
        return False

    occ_x, occ_y, occ_width, occ_height = occlusion_region
    occ_x2 = occ_x + occ_width
    occ_y2 = occ_y + occ_height

    for client in clients:
        if not client.get("mapped", False):
            continue
        client_workspace = client.get("workspace", {})
        if client_workspace.get("id") != workspace:
            continue
        position = client.get("at")
        size = client.get("size")
        if not position or not size:
            continue
        x, y = position
        width, height = size
        win_x1, win_y1 = x, y
        win_x2, win_y2 = x + width, y + height
        if not (win_x2 <= occ_x or win_x1 >= occ_x2 or win_y2 <= occ_y or win_y1 >= occ_y2):
            print(f"[{time.strftime('%H:%M:%S')}] Occlusion detected for window: {client.get('title', 'unknown')}")
            return True
    print(f"[{time.strftime('%H:%M:%S')}] No occlusion detected")
    return False
