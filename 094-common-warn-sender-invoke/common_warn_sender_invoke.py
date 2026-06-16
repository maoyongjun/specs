import os
import logging
import requests
import json
import unittest
from unittest.mock import patch, MagicMock

"""
通用预警插件调用（common_warn_sender）

仿照 Coze Python handler 模式，通过 FC 转发代理异步调用 common_warn_sender 插件。

服务名：service_sys
方法名：测试 common_warn_sender / 正式 common_warn_sender_test
调用方式：HTTP POST 异步（X-Fc-Invocation-Type: Async）
taskObj 结构：CommonWarnSenderInput
  - external_key（str，必填）：格式 externalUserId:empId:campDateId:qwUserId[:debug]
  - sendTemplateList（list[str]，必填）：预警策略编码列表
  - templateVariable（dict，可选）：额外模板变量
  - appendJumpLink（bool，可选，默认 True）：企微消息是否追加聊天跳转链接

需求覆盖：FR-001 ~ FR-010（详见 spec.md）
"""

# ---------------------------------------------------------------------------
# 常量
# ---------------------------------------------------------------------------

# FC 转发代理 URL（可从环境变量 FC_TRANSFER_URL 覆盖）
FC_TRANSFER_URL = os.environ.get("FC_TRANSFER_URL", "https://fc.kkhuacai.cn/transfer/fc")

# 服务名（固定，FR-001）
SERVICE_NAME = "service_sys"

# 方法名：测试 / 正式（FR-003）
FUNCTION_NAME_TEST = "common_warn_sender_test"
FUNCTION_NAME_PROD = "common_warn_sender"

# 日志
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")


# ---------------------------------------------------------------------------
# Coze 插件入口
# ---------------------------------------------------------------------------

def handler(args):
    """
    Coze 插件入口（仿照 warning_emp handler 模式）。

    Parameters:
        args: Coze 运行时注入，args.input 为输入参数对象。

    Returns:
        dict: 调用结果，包含 status / functionName / statusCode。
    """
    input_data = args.input

    # 提取参数 —— Coze 运行时返回的属性可能是代理对象（CozeDict 等），
    # 必须用 _to_plain 递归转为原生 Python 类型，否则 requests.post(json=...)
    # 内部的 complexjson.dumps 无法序列化，会抛 TypeError/ValueError。
    external_key = _to_plain(getattr(input_data, "external_key", None)) or ""
    send_template_list = _to_plain(getattr(input_data, "sendTemplateList", None)) or []
    template_variable = _to_plain(getattr(input_data, "templateVariable", None))
    append_jump_link = _to_plain(getattr(input_data, "appendJumpLink", None))

    # FR-005: external_key 前置校验（与 Python reference 中 empty() 逻辑一致）
    if not _is_not_empty(external_key):
        logger.warning("common_warn_sender_invoke: external_key is empty, skip invoke")
        return {"status": "skip", "message": "external_key is required"}

    # FR-004: sendTemplateList 前置校验
    if not send_template_list:
        logger.warning("common_warn_sender_invoke: sendTemplateList is empty, skip invoke")
        return {"status": "skip", "message": "sendTemplateList is required"}

    # 异步调用（FR-001 / FR-006）
    result = invoke_common_warn_sender_async(
        external_key=external_key,
        send_template_list=send_template_list,
        template_variable=template_variable,
        append_jump_link=append_jump_link,
    )

    return {
        "status": "invoked",
        "functionName": result["functionName"],
        "statusCode": result["statusCode"],
    }


# ---------------------------------------------------------------------------
# 核心调用方法
# ---------------------------------------------------------------------------

def invoke_common_warn_sender_async(external_key, send_template_list,
                                    template_variable=None, append_jump_link=None):
    """
    通过 FC 转发代理异步调用 common_warn_sender 插件（FR-001 / FR-006）。

    调用为 fire-and-forget：发出 HTTP POST 后立即返回，不等待插件执行结果。

    Args:
        external_key (str): 外部键，必填，格式 externalUserId:empId:campDateId:qwUserId[:debug]。
        send_template_list (list[str]): 预警策略编码列表，必填。
        template_variable (dict, optional): 额外模板变量。
        append_jump_link (bool, optional): 企微消息是否追加聊天跳转链接，默认 True。

    Returns:
        dict: {statusCode, functionName, serviceName}

    Raises:
        ValueError: external_key 或 send_template_list 为空时（FR-005 / FR-004）。
        requests.RequestException: HTTP 请求失败时。
    """
    # FR-005: external_key 前置校验
    if not _is_not_empty(external_key):
        raise ValueError("external_key is required and must not be empty")

    # FR-004: sendTemplateList 校验
    if not send_template_list:
        raise ValueError("sendTemplateList is required and must not be empty")

    # FR-003: 按环境确定方法名
    function_name = determine_function_name(external_key)

    # FR-004: 构建 taskObj（CommonWarnSenderInput 结构）
    task_obj = _build_task_obj(
        external_key=external_key,
        send_template_list=send_template_list,
        template_variable=template_variable,
        append_jump_link=append_jump_link,
    )

    # FR-001: 构建请求体
    post_data = {
        "serviceName": SERVICE_NAME,
        "functionName": function_name,
        "taskObj": task_obj,
    }

    # FR-002: 请求头（Content-Type + X-Fc-Invocation-Type: Async）
    headers = {
        "Content-Type": "application/json",
        "X-Fc-Invocation-Type": "Async",
    }

    # FR-006: 异步 fire-and-forget，不阻塞等待结果
    # 使用 data=json.dumps 而非 json= 参数，配合 default=str 兜底，
    # 防止 Coze 运行时代理对象导致 complexjson.dumps 序列化失败。
    try:
        body_str = json.dumps(post_data, ensure_ascii=False, default=str)
    except Exception as e:
        logger.error("common_warn_sender_invoke: JSON serialize failed: %s, data=%s", e, post_data)
        raise
    response = requests.post(FC_TRANSFER_URL, headers=headers, data=body_str)

    # FR-007: 记录调用日志
    ek_summary = external_key[:20] + "..." if len(external_key) > 20 else external_key
    logger.info(
        "common_warn_sender_invoke: url=%s, serviceName=%s, functionName=%s, "
        "external_key=%s, statusCode=%s",
        FC_TRANSFER_URL, SERVICE_NAME, function_name, ek_summary, response.status_code,
    )

    return {
        "statusCode": response.status_code,
        "functionName": function_name,
        "serviceName": SERVICE_NAME,
    }


# ---------------------------------------------------------------------------
# 辅助方法
# ---------------------------------------------------------------------------

def determine_function_name(external_key=""):
    """
    根据环境确定 functionName（FR-003）。

    优先级：
    1. 环境变量 DEPLOY_ENV（值为 'test' 或 'prod'）
    2. 根据 external_key 最后一段后缀判断：
       - 后缀为 "test"  → 测试环境 → common_warn_sender
       - 后缀为 "default"（或其他非 "test" 值）→ 正式环境 → common_warn_sender_test

    external_key 格式示例：
      测试：externalUserId:empId:campDateId:qwUserId:test
      正式：private-domain:companyId:externalUserId:userId:default

    Returns:
        str: 测试环境返回 "common_warn_sender"，正式环境返回 "common_warn_sender_test"
    """
    # 优先从环境变量读取
    env = os.environ.get("DEPLOY_ENV", "").strip().lower()

    if not env:
        # 取 external_key 最后一段（: 分隔）判断环境
        parts = external_key.rsplit(":", 1)
        suffix = parts[1].strip().lower() if len(parts) > 1 else ""
        # 只有显式标记 "test" 才走测试，其余（default / 无后缀 / 其他）一律正式
        env = "test" if suffix == "test" else "prod"

    return FUNCTION_NAME_TEST if env == "test" else FUNCTION_NAME_PROD


def _build_task_obj(external_key, send_template_list,
                    template_variable=None, append_jump_link=None):
    """
    构建 taskObj（CommonWarnSenderInput 结构，FR-004）。

    必填字段：external_key、sendTemplateList
    可选字段：templateVariable、appendJumpLink（默认 True）
    """
    task_obj = {
        "external_key": external_key,
        "sendTemplateList": send_template_list,
    }
    if template_variable is not None:
        task_obj["templateVariable"] = template_variable
    if append_jump_link is not None:
        task_obj["appendJumpLink"] = append_jump_link
    return task_obj


def _is_not_empty(value):
    """判断字符串是否非空（对应 Python reference 中的 empty() 函数）。"""
    return value is not None and str(value).strip() != ""


def _to_plain(obj):
    """
    递归将 Coze 运行时代理对象转为原生 Python 类型。

    Coze 平台的 args.input 属性可能返回 CozeDict / CozeList / CozeObject 等
    代理类型，requests 内置的 complexjson.dumps 无法识别这些类型。
    本方法通过 dict() / list() / str() 递归展开，确保最终结果是
    json.dumps 可直接序列化的纯 Python 对象。
    """
    if obj is None:
        return None
    if isinstance(obj, bool):
        return obj
    if isinstance(obj, (int, float)):
        return obj
    if isinstance(obj, str):
        return obj
    if isinstance(obj, dict):
        return {str(k): _to_plain(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_to_plain(item) for item in obj]
    # Coze 代理对象：尝试 dict() 或 vars() 展开
    if hasattr(obj, "items"):
        try:
            return {str(k): _to_plain(v) for k, v in obj.items()}
        except Exception:
            pass
    if hasattr(obj, "__dict__"):
        try:
            return {str(k): _to_plain(v) for k, v in vars(obj).items() if not k.startswith("_")}
        except Exception:
            pass
    # 最终兜底：转字符串
    return str(obj)


# ---------------------------------------------------------------------------
# 单元测试（FR-010）
# ---------------------------------------------------------------------------

class TestInvokeCommonWarnSender(unittest.TestCase):
    """覆盖 FR-010：HTTP 请求参数断言 + external_key 为空校验。"""

    def _get_post_data(self, mock_post):
        """从 mock 的 requests.post 调用中提取并解析 JSON 请求体。"""
        data_str = mock_post.call_args.kwargs.get("data", "{}")
        return json.loads(data_str)

    # ---- FR-005: external_key 为空前置校验 ----

    def test_empty_external_key_raises_value_error(self):
        """external_key 为空时必须抛出 ValueError，不发 HTTP 请求。"""
        with self.assertRaises(ValueError) as ctx:
            invoke_common_warn_sender_async(
                external_key="",
                send_template_list=["FX_001"],
            )
        self.assertIn("external_key", str(ctx.exception))

    def test_none_external_key_raises_value_error(self):
        """external_key 为 None 时必须抛出 ValueError。"""
        with self.assertRaises(ValueError):
            invoke_common_warn_sender_async(
                external_key=None,
                send_template_list=["FX_001"],
            )

    def test_empty_send_template_list_raises_value_error(self):
        """sendTemplateList 为空时必须抛出 ValueError。"""
        with self.assertRaises(ValueError):
            invoke_common_warn_sender_async(
                external_key="abc:123:456:def",
                send_template_list=[],
            )

    def test_handler_empty_external_key_returns_skip(self):
        """handler 入口：external_key 为空时返回 skip，不发 HTTP 请求。"""
        mock_input = MagicMock()
        mock_input.external_key = ""
        mock_input.sendTemplateList = ["FX_001"]
        mock_input.templateVariable = None
        mock_input.appendJumpLink = None

        mock_args = MagicMock()
        mock_args.input = mock_input

        result = handler(mock_args)
        self.assertEqual(result["status"], "skip")
        self.assertIn("external_key", result["message"])

    # ---- FR-001 / FR-002: HTTP 请求参数断言 ----

    @patch("requests.post")
    def test_invoke_request_url_and_headers(self, mock_post):
        """断言请求 URL、Content-Type 和 X-Fc-Invocation-Type: Async。"""
        mock_response = MagicMock()
        mock_response.status_code = 202
        mock_post.return_value = mock_response

        invoke_common_warn_sender_async(
            external_key="wm2wqaYwAAtOcy1qHMvf77nHDjpHL3QA:4451:3557:NingJingZhiYuan",
            send_template_list=["FX_001"],
        )

        mock_post.assert_called_once()
        call_kwargs = mock_post.call_args

        # 断言 URL
        self.assertEqual(call_kwargs.args[0] if call_kwargs.args else call_kwargs.kwargs.get("url"),
                         FC_TRANSFER_URL)

        # 断言请求头（FR-002）
        headers = call_kwargs.kwargs.get("headers", {})
        self.assertEqual(headers["Content-Type"], "application/json")
        self.assertEqual(headers["X-Fc-Invocation-Type"], "Async")

    @patch("requests.post")
    def test_invoke_request_body_service_name(self, mock_post):
        """断言请求体中 serviceName = 'service_sys'（FR-001）。"""
        mock_response = MagicMock()
        mock_response.status_code = 202
        mock_post.return_value = mock_response

        invoke_common_warn_sender_async(
            external_key="wm2wqaYwAAtOcy1qHMvf77nHDjpHL3QA:4451:3557:NingJingZhiYuan",
            send_template_list=["FX_001"],
        )

        post_data = self._get_post_data(mock_post)
        self.assertEqual(post_data["serviceName"], "service_sys")

    @patch("requests.post")
    def test_invoke_request_body_function_name_test(self, mock_post):
        """断言测试环境 functionName = 'common_warn_sender'（FR-003）。"""
        mock_response = MagicMock()
        mock_response.status_code = 202
        mock_post.return_value = mock_response

        with patch.dict(os.environ, {"DEPLOY_ENV": "test"}):
            invoke_common_warn_sender_async(
                external_key="wm2wqaYwAAtOcy1qHMvf77nHDjpHL3QA:4451:3557:NingJingZhiYuan",
                send_template_list=["FX_001"],
            )
            post_data = self._get_post_data(mock_post)
            self.assertEqual(post_data["functionName"], "common_warn_sender")

    @patch("requests.post")
    def test_invoke_request_body_function_name_prod(self, mock_post):
        """断言正式环境 functionName = 'common_warn_sender_test'（FR-003）。"""
        mock_response = MagicMock()
        mock_response.status_code = 202
        mock_post.return_value = mock_response

        with patch.dict(os.environ, {"DEPLOY_ENV": "prod"}):
            invoke_common_warn_sender_async(
                external_key="wm2wqaYwAAtOcy1qHMvf77nHDjpHL3QA:4451:3557:NingJingZhiYuan",
                send_template_list=["FX_001"],
            )

        post_data = self._get_post_data(mock_post)
        self.assertEqual(post_data["functionName"], "common_warn_sender_test")

    @patch("requests.post")
    def test_invoke_task_obj_required_fields(self, mock_post):
        """断言 taskObj 包含 external_key 和 sendTemplateList（FR-004）。"""
        mock_response = MagicMock()
        mock_response.status_code = 202
        mock_post.return_value = mock_response

        ek = "wm2wqaYwAAtOcy1qHMvf77nHDjpHL3QA:4451:3557:NingJingZhiYuan"
        templates = ["FX_001", "WX_001"]

        with patch.dict(os.environ, {"DEPLOY_ENV": "test"}):
            invoke_common_warn_sender_async(
                external_key=ek,
                send_template_list=templates,
            )

        post_data = self._get_post_data(mock_post)
        task_obj = post_data["taskObj"]
        self.assertEqual(task_obj["external_key"], ek)
        self.assertEqual(task_obj["sendTemplateList"], templates)

    @patch("requests.post")
    def test_invoke_task_obj_optional_fields(self, mock_post):
        """断言 taskObj 可选字段 templateVariable 和 appendJumpLink（FR-004）。"""
        mock_response = MagicMock()
        mock_response.status_code = 202
        mock_post.return_value = mock_response

        ek = "wm2wqaYwAAtOcy1qHMvf77nHDjpHL3QA:4451:3557:NingJingZhiYuan"
        templates = ["FX_001"]
        extra_vars = {"customField": "customValue"}

        with patch.dict(os.environ, {"DEPLOY_ENV": "test"}):
            invoke_common_warn_sender_async(
                external_key=ek,
                send_template_list=templates,
                template_variable=extra_vars,
                append_jump_link=False,
            )

        task_obj = self._get_post_data(mock_post)["taskObj"]
        self.assertEqual(task_obj["templateVariable"], extra_vars)
        self.assertFalse(task_obj["appendJumpLink"])

    @patch("requests.post")
    def test_invoke_task_obj_no_optional_when_none(self, mock_post):
        """可选字段为 None 时不出现在 taskObj 中。"""
        mock_response = MagicMock()
        mock_response.status_code = 202
        mock_post.return_value = mock_response

        with patch.dict(os.environ, {"DEPLOY_ENV": "test"}):
            invoke_common_warn_sender_async(
                external_key="abc:1:2:def",
                send_template_list=["FX_001"],
                template_variable=None,
                append_jump_link=None,
            )

        task_obj = self._get_post_data(mock_post)["taskObj"]
        self.assertNotIn("templateVariable", task_obj)
        self.assertNotIn("appendJumpLink", task_obj)

    # ---- FR-006: 异步 fire-and-forget ----

    @patch("requests.post")
    def test_invoke_returns_immediately(self, mock_post):
        """异步调用应立即返回，不阻塞（FR-006）。"""
        mock_response = MagicMock()
        mock_response.status_code = 202
        mock_post.return_value = mock_response

        result = invoke_common_warn_sender_async(
            external_key="abc:1:2:def",
            send_template_list=["FX_001"],
        )

        self.assertEqual(result["statusCode"], 202)
        self.assertIn("functionName", result)
        self.assertIn("serviceName", result)

    # ---- FR-003: 环境判断 ----

    def test_determine_function_name_env_test(self):
        """DEPLOY_ENV=test → common_warn_sender。"""
        with patch.dict(os.environ, {"DEPLOY_ENV": "test"}):
            self.assertEqual(determine_function_name(), FUNCTION_NAME_TEST)

    def test_determine_function_name_env_prod(self):
        """DEPLOY_ENV=prod → common_warn_sender_test。"""
        with patch.dict(os.environ, {"DEPLOY_ENV": "prod"}):
            self.assertEqual(determine_function_name(), FUNCTION_NAME_PROD)

    def test_determine_function_name_by_external_key_suffix(self):
        """无 DEPLOY_ENV 时，external_key 后缀为 'test' → common_warn_sender。"""
        with patch.dict(os.environ, {}, clear=True):
            # 清除 DEPLOY_ENV 确保走后缀判断
            os.environ.pop("DEPLOY_ENV", None)
            name = determine_function_name("abc:1:2:def:test")
            self.assertEqual(name, FUNCTION_NAME_TEST)

    def test_determine_function_name_by_external_key_no_suffix(self):
        """无 DEPLOY_ENV 时，external_key 无 'test' 后缀 → common_warn_sender_test。"""
        with patch.dict(os.environ, {}, clear=True):
            os.environ.pop("DEPLOY_ENV", None)
            name = determine_function_name("abc:1:2:def")
            self.assertEqual(name, FUNCTION_NAME_PROD)

    def test_determine_function_name_default_suffix_is_prod(self):
        """external_key 后缀为 'default' → 正式环境 common_warn_sender_test。"""
        with patch.dict(os.environ, {}, clear=True):
            os.environ.pop("DEPLOY_ENV", None)
            name = determine_function_name(
                "private-domain:7644449532675866662:wmQcc1XAAA6t6wBanYmYTH7lBFlxkb5A:11311073569:default"
            )
            self.assertEqual(name, FUNCTION_NAME_PROD)

    # ---- _to_plain: Coze 代理对象转换 ----

    def test_to_plain_none(self):
        self.assertIsNone(_to_plain(None))

    def test_to_plain_str(self):
        self.assertEqual(_to_plain("hello"), "hello")

    def test_to_plain_bool(self):
        self.assertTrue(_to_plain(True))
        self.assertFalse(_to_plain(False))

    def test_to_plain_int(self):
        self.assertEqual(_to_plain(42), 42)

    def test_to_plain_dict(self):
        self.assertEqual(_to_plain({"a": 1, "b": "x"}), {"a": 1, "b": "x"})

    def test_to_plain_list(self):
        self.assertEqual(_to_plain(["a", "b"]), ["a", "b"])

    def test_to_plain_nested(self):
        data = {"list": [{"key": "val"}], "num": 1}
        self.assertEqual(_to_plain(data), {"list": [{"key": "val"}], "num": 1})

    def test_to_plain_coze_like_dict_proxy(self):
        """模拟 Coze 运行时返回的 dict-like 代理对象。"""
        class CozeDict:
            def __init__(self, d):
                self._data = d
            def items(self):
                return self._data.items()
        proxy = CozeDict({"studentName": "xxx", "age": 18})
        result = _to_plain(proxy)
        self.assertEqual(result, {"studentName": "xxx", "age": 18})
        # 结果必须是可 JSON 序列化的
        json.dumps(result)

    def test_to_plain_coze_like_object(self):
        """模拟 Coze 运行时返回的带 __dict__ 的代理对象。"""
        class CozeObj:
            def __init__(self):
                self.studentName = "xxx"
                self.score = 95
        result = _to_plain(CozeObj())
        self.assertEqual(result, {"studentName": "xxx", "score": 95})
        json.dumps(result)

    @patch("requests.post")
    def test_invoke_with_string_false_append_jump_link(self, mock_post):
        """断言 appendJumpLink 传入字符串 'false' 时不导致序列化失败。"""
        mock_response = MagicMock()
        mock_response.status_code = 202
        mock_post.return_value = mock_response

        with patch.dict(os.environ, {"DEPLOY_ENV": "test"}):
            invoke_common_warn_sender_async(
                external_key="abc:1:2:def",
                send_template_list=["WX999"],
                template_variable={"studentName": "xxx"},
                append_jump_link="false",
            )

        post_data = self._get_post_data(mock_post)
        self.assertEqual(post_data["taskObj"]["appendJumpLink"], "false")
        self.assertEqual(post_data["taskObj"]["templateVariable"], {"studentName": "xxx"})


if __name__ == "__main__":
    unittest.main()
