/*
 * Madout2 Force Criminal Plugin - 简化版
 * 
 * 使用方法：
 * 1. 编译成 dylib
 * 2. 注入游戏
 * 3. 调用 SetForceCriminalEnabled(true)
 * 
 * 编译命令：
 * clang++ -arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
 *   -miphoneos-version-min=11.0 -fPIC -shared -O2 \
 *   SimpleForceCriminal.mm -o SimpleForceCriminal.dylib
 */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <mach/mach.h>

// ============================================
// 配置参数
// ============================================

static bool g_Enabled = false;
static int g_TargetUserId = -1;  // -1 = 全体玩家
static int g_TargetStars = 5;
static pthread_t g_WorkerThread = 0;
static bool g_Running = false;

// ============================================
// IL2CPP API 函数指针（简化版）
// ============================================

typedef void* (*il2cpp_class_from_name_t)(void*, const char*, const char*);
typedef void* (*il2cpp_class_get_field_from_name_t)(void*, const char*);
typedef void (*il2cpp_field_static_get_value_t)(void*, void*);
typedef size_t (*il2cpp_array_length_t)(void*);
typedef void* (*il2cpp_array_get_t)(void*, size_t);

static void* g_UnityFramework = NULL;
static il2cpp_class_from_name_t il2cpp_class_from_name = NULL;
static il2cpp_class_get_field_from_name_t il2cpp_class_get_field_from_name = NULL;
static il2cpp_field_static_get_value_t il2cpp_field_static_get_value = NULL;
static il2cpp_array_length_t il2cpp_array_length = NULL;
static il2cpp_array_get_t il2cpp_array_get = NULL;

// ============================================
// 内存读写工具
// ============================================

template<typename T>
static T ReadMemory(void* address) {
    if (!address) return T();
    T value;
    memcpy(&value, address, sizeof(T));
    return value;
}

template<typename T>
static void WriteMemory(void* address, T value) {
    if (!address) return;
    
    // 获取写权限
    vm_protect(mach_task_self(), 
               (vm_address_t)address, 
               sizeof(T), 
               FALSE, 
               VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    
    memcpy(address, &value, sizeof(T));
    
    // 恢复保护
    vm_protect(mach_task_self(), 
               (vm_address_t)address, 
               sizeof(T), 
               FALSE, 
               VM_PROT_READ | VM_PROT_EXECUTE);
}

// ============================================
// 核心功能
// ============================================

// 初始化 IL2CPP API
static bool InitIL2CPP() {
    if (g_UnityFramework) return true;
    
    g_UnityFramework = dlopen("UnityFramework", RTLD_NOW);
    if (!g_UnityFramework) {
        printf("[ForceCriminal] Failed to load UnityFramework\n");
        return false;
    }
    
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(g_UnityFramework, "il2cpp_class_from_name");
    il2cpp_class_get_field_from_name = (il2cpp_class_get_field_from_name_t)dlsym(g_UnityFramework, "il2cpp_class_get_field_from_name");
    il2cpp_field_static_get_value = (il2cpp_field_static_get_value_t)dlsym(g_UnityFramework, "il2cpp_field_static_get_value");
    il2cpp_array_length = (il2cpp_array_length_t)dlsym(g_UnityFramework, "il2cpp_array_length");
    il2cpp_array_get = (il2cpp_array_get_t)dlsym(g_UnityFramework, "il2cpp_array_get");
    
    if (!il2cpp_class_from_name) {
        printf("[ForceCriminal] Failed to get IL2CPP API\n");
        return false;
    }
    
    printf("[ForceCriminal] IL2CPP API loaded\n");
    return true;
}

// 修改玩家为罪犯（简化版 - 直接内存修改）
static void SetPlayerCriminal(void* netUser) {
    if (!netUser) return;
    
    // 关键偏移量（从 dump.cs 提取）
    // NetUser.user_id: 0x78
    // NetUser.WantedRate: 0x198
    // NetUserWantedRate._type_Sync: 0x98
    // NetUserWantedRate.Stars_Sync: 0x70
    
    // 读取玩家 ID
    int userId = ReadMemory<int>((void*)((uintptr_t)netUser + 0x78));
    
    // 读取 WantedRate 组件
    void* wantedRate = ReadMemory<void*>((void*)((uintptr_t)netUser + 0x198));
    if (!wantedRate) {
        printf("[ForceCriminal] Player %d has no WantedRate\n", userId);
        return;
    }
    
    // 设置罪犯类型 = 3 (PlayerKiller)
    WriteMemory<int>((void*)((uintptr_t)wantedRate + 0x98), 3);
    
    // 设置星级
    WriteMemory<float>((void*)((uintptr_t)wantedRate + 0x70), (float)g_TargetStars);
    
    printf("[ForceCriminal] Set player %d as %d-star criminal\n", userId, g_TargetStars);
}

// 工作线程
static void* WorkerThread(void* arg) {
    printf("[ForceCriminal] Worker started\n");
    
    while (g_Running) {
        if (g_Enabled && g_UnityFramework) {
            // 这里可以添加遍历玩家的逻辑
            // 简化版：需要从 H5GG 或其他工具传入玩家地址
            
            printf("[ForceCriminal] Worker running (enabled=%d)\n", g_Enabled);
        }
        
        sleep(1);
    }
    
    printf("[ForceCriminal] Worker stopped\n");
    return NULL;
}

// ============================================
// 公开 API（H5GG 可调用）
// ============================================

extern "C" {
    
    // 启用/禁用功能
    void SetForceCriminalEnabled(bool enabled) {
        g_Enabled = enabled;
        printf("[ForceCriminal] %s\n", enabled ? "Enabled" : "Disabled");
    }
    
    // 设置目标玩家 ID
    void SetTargetUserId(int userId) {
        g_TargetUserId = userId;
        printf("[ForceCriminal] Target user: %d\n", userId);
    }
    
    // 设置目标星级
    void SetTargetStars(int stars) {
        if (stars >= 1 && stars <= 5) {
            g_TargetStars = stars;
            printf("[ForceCriminal] Target stars: %d\n", stars);
        }
    }
    
    // 手动修改指定玩家（传入 NetUser 地址）
    void ModifyPlayer(void* netUserAddress) {
        if (!g_Enabled) {
            printf("[ForceCriminal] Feature disabled\n");
            return;
        }
        SetPlayerCriminal(netUserAddress);
    }
    
    // 初始化（必须在游戏加载后调用）
    bool InitPlugin() {
        return InitIL2CPP();
    }
    
    // 获取状态
    bool IsEnabled() {
        return g_Enabled;
    }
    
    int GetTargetStars() {
        return g_TargetStars;
    }
}

// ============================================
// dylib 入口
// ============================================

__attribute__((constructor))
static void initialize() {
    printf("[ForceCriminal] Plugin loaded\n");
    printf("[ForceCriminal] Version: 1.0.0 (Simplified)\n");
    
    g_Running = true;
    pthread_create(&g_WorkerThread, NULL, WorkerThread, NULL);
    
    printf("[ForceCriminal] Ready - Call InitPlugin() after game loads\n");
}

__attribute__((destructor))
static void cleanup() {
    printf("[ForceCriminal] Plugin unloading\n");
    
    g_Running = false;
    g_Enabled = false;
    
    if (g_WorkerThread) {
        pthread_join(g_WorkerThread, NULL);
    }
    
    if (g_UnityFramework) {
        dlclose(g_UnityFramework);
    }
    
    printf("[ForceCriminal] Unloaded\n");
}
